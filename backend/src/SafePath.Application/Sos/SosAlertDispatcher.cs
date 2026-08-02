using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// SOS-only multi-channel fan-out. This class is structurally incapable of writing
/// <see cref="SosDeliveryStatus.Delivered"/> or <see cref="SosDeliveryStatus.Acknowledged"/> —
/// those two states are only ever written by AlertHub.ConfirmReceipt (SignalR), the FCM receipt
/// callback added in plan 03-06, the Twilio status webhook added in plan 03-05, and
/// AcknowledgeSosCommand. Do not "helpfully" mark a row Delivered on a successful send here:
/// dispatching to a channel proves nothing about whether it actually arrived (D-10,
/// 03-RESEARCH.md Pitfall 1). Each channel's dispatch is independently try/caught so one dead
/// channel can never take the whole emergency down (03-RESEARCH.md "hidden single point of
/// failure").
/// </summary>
public class SosAlertDispatcher : ISosAlertDispatcher
{
    private readonly IApplicationDbContext _db;
    private readonly IAlertBroadcastService _broadcast;
    private readonly ISmsGateway _smsGateway;

    public SosAlertDispatcher(IApplicationDbContext db, IAlertBroadcastService broadcast, ISmsGateway smsGateway)
    {
        _db = db;
        _broadcast = broadcast;
        _smsGateway = smsGateway;
    }

    public async Task DispatchAsync(Guid sosSessionId, CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == sosSessionId, cancellationToken);
        if (session is null)
        {
            return;
        }

        var attempts = await _db.SosDeliveryAttempts
            .Where(a => a.SosSessionId == sosSessionId)
            .ToListAsync(cancellationToken);

        foreach (var channelAttempts in attempts.GroupBy(a => a.Channel))
        {
            var channel = channelAttempts.Key;
            var rows = channelAttempts.ToList();

            try
            {
                switch (channel)
                {
                    case AlertChannel.SignalR:
                        await DispatchSignalR(session, rows, cancellationToken);
                        break;

                    case AlertChannel.Fcm:
                        // 03-06 fills in the FCM push arm — the single extension point for that plan.
                        break;

                    case AlertChannel.Sms:
                        await DispatchSms(session, rows, cancellationToken);
                        break;
                }
            }
            catch (Exception ex)
            {
                await MarkChannelFailed(rows, ex, cancellationToken);
            }
        }
    }

    private async Task DispatchSignalR(
        SosSession session,
        List<SosDeliveryAttempt> attempts,
        CancellationToken cancellationToken)
    {
        var recipientUserIds = attempts
            .Where(a => a.RecipientUserId.HasValue)
            .Select(a => a.RecipientUserId!.Value)
            .Distinct()
            .ToList();

        if (recipientUserIds.Count == 0)
        {
            return;
        }

        var queuedAtUtc = DateTime.UtcNow;
        foreach (var attempt in attempts.Where(a => a.RecipientUserId.HasValue))
        {
            attempt.Status = SosDeliveryStatus.Queued;
            attempt.QueuedAtUtc = queuedAtUtc;
        }

        await _db.SaveChangesAsync(cancellationToken);

        var dto = await SosSessionProjection.ProjectAsync(_db, session, cancellationToken);
        await _broadcast.SosTriggered(session.FamilyId, recipientUserIds, dto, cancellationToken);
    }

    /// <summary>
    /// Sends one SMS per emergency-contact delivery row via <see cref="ISmsGateway"/>. A
    /// per-contact failure marks only that contact's row Failed (never the whole channel), so
    /// one bad number does not swallow a successfully-queued send to another contact. The
    /// gateway returning successfully means only that the provider accepted the message — this
    /// method never writes <see cref="SosDeliveryStatus.Delivered"/>, which only the Task 3
    /// status webhook may do.
    /// </summary>
    private async Task DispatchSms(
        SosSession session,
        List<SosDeliveryAttempt> attempts,
        CancellationToken cancellationToken)
    {
        var contactRows = attempts.Where(a => a.EmergencyContactId.HasValue).ToList();
        if (contactRows.Count == 0)
        {
            return;
        }

        var contactIds = contactRows.Select(a => a.EmergencyContactId!.Value).Distinct().ToList();
        var contacts = await _db.EmergencyContacts
            .Where(c => contactIds.Contains(c.Id))
            .ToDictionaryAsync(c => c.Id, cancellationToken);

        var senderName = await _db.Users
            .Where(u => u.Id == session.TriggeredByUserId)
            .Select(u => string.IsNullOrWhiteSpace(u.DisplayName) ? u.FullName : u.DisplayName!)
            .SingleOrDefaultAsync(cancellationToken);
        senderName = string.IsNullOrWhiteSpace(senderName) ? "A family member" : senderName;

        var body = ComposeSmsBody(senderName, session.Latitude, session.Longitude);

        foreach (var attempt in contactRows)
        {
            if (!contacts.TryGetValue(attempt.EmergencyContactId!.Value, out var contact))
            {
                continue;
            }

            try
            {
                var result = await _smsGateway.SendAsync(contact.PhoneNumberE164, body, cancellationToken);
                attempt.Status = SosDeliveryStatus.Queued;
                attempt.QueuedAtUtc = DateTime.UtcNow;
                attempt.ProviderMessageId = result.ProviderMessageId;
            }
            catch (Exception ex)
            {
                attempt.Status = SosDeliveryStatus.Failed;
                attempt.FailureReason = ex.Message.Length > 500 ? ex.Message[..500] : ex.Message;
            }
        }

        await _db.SaveChangesAsync(cancellationToken);
    }

    /// <summary>
    /// Sender display name + a short emergency statement + a maps link built from the session's
    /// coordinates (omitted when null) — never the recipient's own phone number. Kept under 320
    /// characters (at most two SMS segments on a trial balance).
    /// </summary>
    private static string ComposeSmsBody(string senderDisplayName, double? latitude, double? longitude)
    {
        var body = $"{senderDisplayName} triggered an SOS on SafePath and needs help.";
        if (latitude is { } lat && longitude is { } lng)
        {
            body += $" Location: https://maps.google.com/?q={lat},{lng}";
        }

        return body.Length > 320 ? body[..320] : body;
    }

    private async Task MarkChannelFailed(
        List<SosDeliveryAttempt> attempts,
        Exception ex,
        CancellationToken cancellationToken)
    {
        var reason = ex.Message.Length > 500 ? ex.Message[..500] : ex.Message;
        foreach (var attempt in attempts)
        {
            attempt.Status = SosDeliveryStatus.Failed;
            attempt.FailureReason = reason;
        }

        await _db.SaveChangesAsync(cancellationToken);
    }
}
