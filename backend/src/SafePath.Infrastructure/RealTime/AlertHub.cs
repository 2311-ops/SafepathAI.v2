using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Domain.Enums;

namespace SafePath.Infrastructure.RealTime;

/// <summary>
/// Dedicated, authenticated SignalR hub for emergency traffic — structurally isolated from
/// <see cref="LocationHub"/> so nothing in the routine location pipeline can ever slow the SOS
/// path down (Core Value). Occupies its own group namespace via <see cref="FamilyGroupName"/>,
/// so a LocationHub group membership grants nothing here. This hub injects no
/// <c>PresenceTracker</c> and no command handler beyond what it needs directly — its only jobs
/// are delivery-receipt confirmation here and, from plan 03-08, live-location window streaming.
/// </summary>
[Authorize]
public class AlertHub : Hub<IAlertClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IApplicationDbContext _db;
    private readonly IAlertBroadcastService _broadcast;

    public AlertHub(
        IFamilyAuthorizationService authorization,
        IApplicationDbContext db,
        IAlertBroadcastService broadcast)
    {
        _authorization = authorization;
        _db = db;
        _broadcast = broadcast;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        var familyId = GetFamilyIdFromQuery();

        await _authorization.RequireMembership(userId, familyId, Context.ConnectionAborted);

        await Groups.AddToGroupAsync(Context.ConnectionId, FamilyGroupName(familyId), Context.ConnectionAborted);

        await base.OnConnectedAsync();
    }

    /// <summary>
    /// Records that this connection's user actually received an SOS push. This is what makes
    /// "Delivered" truthful: <c>Clients.Users(...).SosTriggered(...)</c> returning tells you
    /// nothing about whether the client actually processed the message (03-RESEARCH.md
    /// Pitfall 1), so the sender's UI may only show Delivered once this method has fired.
    /// Guarded by <see cref="IFamilyAuthorizationService.RequireMembership"/> on the session's
    /// family, and only ever updates the caller's own row — a client cannot forge another
    /// recipient's receipt (threat T-03-13).
    /// </summary>
    public async Task ConfirmReceipt(Guid sosSessionId)
    {
        var userId = GetUserId();

        var session = await _db.SosSessions.SingleOrDefaultAsync(
            s => s.Id == sosSessionId, Context.ConnectionAborted);
        if (session is null)
        {
            return;
        }

        await _authorization.RequireMembership(userId, session.FamilyId, Context.ConnectionAborted);

        var attempt = await _db.SosDeliveryAttempts.SingleOrDefaultAsync(
            a => a.SosSessionId == sosSessionId
                && a.RecipientUserId == userId
                && a.Channel == AlertChannel.SignalR,
            Context.ConnectionAborted);
        if (attempt is null)
        {
            return;
        }

        var deliveredAtUtc = DateTime.UtcNow;
        attempt.Status = SosDeliveryStatus.Delivered;
        attempt.DeliveredAtUtc = deliveredAtUtc;
        await _db.SaveChangesAsync(Context.ConnectionAborted);

        var recipientIds = await _db.SosDeliveryAttempts
            .Where(a => a.SosSessionId == sosSessionId && a.RecipientUserId != null)
            .Select(a => a.RecipientUserId!.Value)
            .Distinct()
            .ToListAsync(Context.ConnectionAborted);

        await _broadcast.DeliveryStatusChanged(
            session.FamilyId,
            recipientIds,
            new SosDeliveryStatusChangedDto(
                sosSessionId,
                userId,
                null,
                AlertChannel.SignalR,
                SosDeliveryStatus.Delivered,
                deliveredAtUtc),
            Context.ConnectionAborted);
    }

    public static string FamilyGroupName(Guid familyId) => $"alert:family:{familyId}";

    private Guid GetUserId()
    {
        if (Guid.TryParse(Context.UserIdentifier, out var userId))
        {
            return userId;
        }

        throw new HubException("Missing authenticated user.");
    }

    private Guid GetFamilyIdFromQuery()
    {
        if (TryGetFamilyIdFromQuery(out var familyId))
        {
            return familyId;
        }

        throw new HubException("A valid familyId query parameter is required.");
    }

    private bool TryGetFamilyIdFromQuery(out Guid familyId)
    {
        familyId = default;
        var rawFamilyId = Context.GetHttpContext()?.Request.Query["familyId"].ToString();
        return Guid.TryParse(rawFamilyId, out familyId);
    }
}
