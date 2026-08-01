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

    public SosAlertDispatcher(IApplicationDbContext db, IAlertBroadcastService broadcast)
    {
        _db = db;
        _broadcast = broadcast;
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
                        // 03-05 fills in the Twilio SMS arm — the single extension point for that plan.
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
