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
    private readonly IPushSender _pushSender;

    public SosAlertDispatcher(
        IApplicationDbContext db,
        IAlertBroadcastService broadcast,
        ISmsGateway smsGateway,
        IPushSender pushSender)
    {
        _db = db;
        _broadcast = broadcast;
        _smsGateway = smsGateway;
        _pushSender = pushSender;
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
                        await DispatchFcm(session, rows, cancellationToken);
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

        // The fan-out's own address list (recipientUserIds, above) is already exactly this
        // session's distinct delivery-attempt recipient set — the one condition that makes
        // ProjectForRecipientAudienceAsync's unconditional visibility safe (T-RK2-02). This is
        // the only call site in the codebase allowed to use it.
        var dto = await SosSessionProjection.ProjectForRecipientAudienceAsync(_db, session, cancellationToken);
        await _broadcast.SosTriggered(session.FamilyId, recipientUserIds, dto, cancellationToken);
    }

    /// <summary>
    /// Sends one FCM multicast per Guardian recipient row, fanning out to every device that
    /// recipient has registered (D-32 — a guardian with a phone and a tablet is alerted on
    /// both). A recipient with zero registered tokens is marked <see cref="SosDeliveryStatus.Failed"/>
    /// with a reason naming the missing registration, rather than silently looking queued —
    /// an honest amber state beats a misleading one. This method never writes
    /// <see cref="SosDeliveryStatus.Delivered"/>: FCM's send API only confirms Google accepted
    /// the message, never that a device received it (D-10, 03-RESEARCH.md Pitfall 1) —
    /// <c>ConfirmPushReceiptCommand</c> is the only path allowed to do that.
    /// </summary>
    private async Task DispatchFcm(
        SosSession session,
        List<SosDeliveryAttempt> attempts,
        CancellationToken cancellationToken)
    {
        var recipientRows = attempts.Where(a => a.RecipientUserId.HasValue).ToList();
        if (recipientRows.Count == 0)
        {
            return;
        }

        var senderName = await _db.Users
            .Where(u => u.Id == session.TriggeredByUserId)
            .Select(u => string.IsNullOrWhiteSpace(u.DisplayName) ? u.FullName : u.DisplayName!)
            .SingleOrDefaultAsync(cancellationToken);
        senderName = string.IsNullOrWhiteSpace(senderName) ? "A family member" : senderName;

        var recipientUserIds = recipientRows.Select(a => a.RecipientUserId!.Value).Distinct().ToList();
        var tokensByUser = await _db.UserDeviceTokens
            .Where(t => recipientUserIds.Contains(t.UserId))
            .ToListAsync(cancellationToken);

        var message = new PushMessage(
            Title: "SafePath SOS",
            Body: $"{senderName} needs help.",
            Data: new Dictionary<string, string>
            {
                ["type"] = "sos",
                ["sosSessionId"] = session.Id.ToString(),
                ["senderDisplayName"] = senderName,
                ["triggeredAtUtc"] = session.TriggeredAtUtc.ToString("O"),
            });

        foreach (var attempt in recipientRows)
        {
            var recipientTokenRows = tokensByUser.Where(t => t.UserId == attempt.RecipientUserId!.Value).ToList();
            if (recipientTokenRows.Count == 0)
            {
                attempt.Status = SosDeliveryStatus.Failed;
                attempt.FailureReason = "No registered device token for this recipient.";
                continue;
            }

            var tokens = recipientTokenRows.Select(t => t.Token).ToList();
            var result = await _pushSender.SendAsync(tokens, message, cancellationToken);

            if (result.InvalidTokens.Count > 0)
            {
                var invalid = recipientTokenRows.Where(t => result.InvalidTokens.Contains(t.Token)).ToList();
                _db.UserDeviceTokens.RemoveRange(invalid);
            }

            attempt.Status = SosDeliveryStatus.Queued;
            attempt.QueuedAtUtc = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(cancellationToken);
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
