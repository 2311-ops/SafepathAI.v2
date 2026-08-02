using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// Carries the raw inbound webhook request pieces (never a pre-parsed/trusted status) so
/// signature validation happens inside the handler, before any mutation — never in the
/// controller alone, and never skippable by a caller of this command.
/// </summary>
public record RecordSmsDeliveryStatusCommand(
    string RequestUrl,
    IReadOnlyDictionary<string, string> FormParameters,
    string? SignatureHeader);

public record RecordSmsDeliveryStatusResult(bool SignatureValid, bool Applied);

/// <summary>
/// Accepts Twilio's (or any configured provider's) delivery-status callback. A signature that
/// does not validate mutates nothing (threat T-03-19). An unrecognised <c>ProviderMessageId</c>
/// or a status that only means "still in flight" (queued/sending/sent) also mutates nothing —
/// this is the only path allowed to write <see cref="SosDeliveryStatus.Delivered"/> for the SMS
/// channel (D-10, 03-RESEARCH.md Pitfall 1).
/// </summary>
public class RecordSmsDeliveryStatusCommandHandler : ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IAlertBroadcastService _broadcast;
    private readonly ISmsWebhookSignatureValidator _signatureValidator;

    public RecordSmsDeliveryStatusCommandHandler(
        IApplicationDbContext db,
        IAlertBroadcastService broadcast,
        ISmsWebhookSignatureValidator signatureValidator)
    {
        _db = db;
        _broadcast = broadcast;
        _signatureValidator = signatureValidator;
    }

    public async Task<RecordSmsDeliveryStatusResult> Handle(
        RecordSmsDeliveryStatusCommand command,
        CancellationToken cancellationToken = default)
    {
        if (!_signatureValidator.IsValid(command.RequestUrl, command.FormParameters, command.SignatureHeader))
        {
            return new RecordSmsDeliveryStatusResult(SignatureValid: false, Applied: false);
        }

        var messageSid = GetFirst(command.FormParameters, "MessageSid", "SmsSid");
        var providerStatus = GetFirst(command.FormParameters, "MessageStatus", "SmsStatus");

        if (string.IsNullOrWhiteSpace(messageSid) || string.IsNullOrWhiteSpace(providerStatus))
        {
            return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: false);
        }

        var attempt = await _db.SosDeliveryAttempts
            .SingleOrDefaultAsync(a => a.ProviderMessageId == messageSid, cancellationToken);

        if (attempt is null)
        {
            // Unknown id: return success without mutating anything so a stray retry cannot
            // corrupt state or put the provider into a retry loop.
            return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: false);
        }

        switch (providerStatus.Trim().ToLowerInvariant())
        {
            case "delivered":
                attempt.Status = SosDeliveryStatus.Delivered;
                attempt.DeliveredAtUtc = DateTime.UtcNow;
                break;

            case "undelivered":
            case "failed":
                attempt.Status = SosDeliveryStatus.Failed;
                attempt.FailureReason = GetFirst(command.FormParameters, "ErrorCode");
                break;

            default:
                // queued / sending / sent -- the message has still only been accepted, not
                // received. Do not mutate.
                return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: false);
        }

        await _db.SaveChangesAsync(cancellationToken);

        var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == attempt.SosSessionId, cancellationToken);
        if (session is not null)
        {
            var recipientUserIds = await SosSessionProjection.ResolveRecipientUserIds(_db, session.Id, cancellationToken);
            var broadcastRecipients = recipientUserIds.Append(session.TriggeredByUserId).Distinct();

            await _broadcast.DeliveryStatusChanged(
                session.FamilyId,
                broadcastRecipients,
                new SosDeliveryStatusChangedDto(
                    session.Id,
                    attempt.RecipientUserId,
                    attempt.EmergencyContactId,
                    attempt.Channel,
                    attempt.Status,
                    DateTime.UtcNow),
                cancellationToken);
        }

        return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: true);
    }

    private static string? GetFirst(IReadOnlyDictionary<string, string> parameters, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (parameters.TryGetValue(key, out var value) && !string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return null;
    }
}
