using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// Carries the raw inbound webhook request pieces (never a pre-parsed/trusted status) so
/// signature validation happens inside the handler, before any mutation — never in the
/// controller alone, and never skippable by a caller of this command. The signature is computed
/// over the exact request bytes, so the raw body string (not a re-serialized/form-decoded
/// representation) must be preserved end to end.
/// </summary>
public record RecordSmsDeliveryStatusCommand(string RawBody, string? SignatureHeader);

public record RecordSmsDeliveryStatusResult(bool SignatureValid, bool Applied);

/// <summary>
/// Accepts the WhatsApp Business Cloud API's (or any configured provider's) delivery-status
/// callback. A signature that does not validate mutates nothing (threat T-WGL-02). An
/// unrecognised <c>ProviderMessageId</c> or a status that only means "still in flight" (e.g.
/// WhatsApp's <c>sent</c>) also mutates nothing — this is the only path allowed to write
/// <see cref="SosDeliveryStatus.Delivered"/> for the SMS channel (D-10, 03-RESEARCH.md Pitfall
/// 1).
/// </summary>
public class RecordSmsDeliveryStatusCommandHandler : ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IAlertBroadcastService _broadcast;
    private readonly ISmsWebhookSignatureValidator _signatureValidator;
    private readonly ISmsDeliveryStatusParser _parser;

    public RecordSmsDeliveryStatusCommandHandler(
        IApplicationDbContext db,
        IAlertBroadcastService broadcast,
        ISmsWebhookSignatureValidator signatureValidator,
        ISmsDeliveryStatusParser parser)
    {
        _db = db;
        _broadcast = broadcast;
        _signatureValidator = signatureValidator;
        _parser = parser;
    }

    public async Task<RecordSmsDeliveryStatusResult> Handle(
        RecordSmsDeliveryStatusCommand command,
        CancellationToken cancellationToken = default)
    {
        if (!_signatureValidator.IsValid(command.RawBody, command.SignatureHeader))
        {
            return new RecordSmsDeliveryStatusResult(SignatureValid: false, Applied: false);
        }

        var updates = _parser.Parse(command.RawBody);
        if (updates.Count == 0)
        {
            return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: false);
        }

        var mutatedAttempts = new List<SafePath.Domain.Entities.SosDeliveryAttempt>();

        foreach (var update in updates)
        {
            var attempt = await _db.SosDeliveryAttempts
                .SingleOrDefaultAsync(a => a.ProviderMessageId == update.ProviderMessageId, cancellationToken);

            if (attempt is null)
            {
                // Unknown id: skip without mutating anything so a stray retry cannot corrupt
                // state or put the provider into a retry loop.
                continue;
            }

            switch (update.Outcome)
            {
                case SmsDeliveryOutcome.Delivered:
                    attempt.Status = SosDeliveryStatus.Delivered;
                    attempt.DeliveredAtUtc = DateTime.UtcNow;
                    break;

                case SmsDeliveryOutcome.Failed:
                    attempt.Status = SosDeliveryStatus.Failed;
                    attempt.FailureReason = update.FailureReason;
                    break;
            }

            mutatedAttempts.Add(attempt);
        }

        if (mutatedAttempts.Count == 0)
        {
            return new RecordSmsDeliveryStatusResult(SignatureValid: true, Applied: false);
        }

        await _db.SaveChangesAsync(cancellationToken);

        foreach (var attempt in mutatedAttempts)
        {
            var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == attempt.SosSessionId, cancellationToken);
            if (session is null)
            {
                continue;
            }

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
}
