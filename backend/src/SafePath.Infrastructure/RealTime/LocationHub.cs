using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;

namespace SafePath.Infrastructure.RealTime;

public record ReportLocationRequest(
    double Latitude,
    double Longitude,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc);

[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly PresenceTracker _presence;
    private readonly ICommandHandler<ReportLocationCommand, ReportLocationResult> _reportLocation;

    public LocationHub(
        IFamilyAuthorizationService authorization,
        PresenceTracker presence,
        ICommandHandler<ReportLocationCommand, ReportLocationResult> reportLocation)
    {
        _authorization = authorization;
        _presence = presence;
        _reportLocation = reportLocation;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        var familyId = GetFamilyIdFromQuery();

        await _authorization.RequireMembership(userId, familyId, Context.ConnectionAborted);

        var groupName = FamilyGroupName(familyId);
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName, Context.ConnectionAborted);

        var changedAtUtc = DateTime.UtcNow;
        var wasOffline = _presence.AddConnection(userId, Context.ConnectionId, changedAtUtc);
        if (wasOffline)
        {
            await Clients.OthersInGroup(groupName)
                .PresenceChanged(new PresenceChangeDto(userId, IsOnline: true, changedAtUtc));
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Guid.TryParse(Context.UserIdentifier, out var userId))
        {
            var changedAtUtc = DateTime.UtcNow;
            var stillOnline = _presence.RemoveConnection(userId, Context.ConnectionId, changedAtUtc);
            if (!stillOnline && TryGetFamilyIdFromQuery(out var familyId))
            {
                await Clients.OthersInGroup(FamilyGroupName(familyId))
                    .PresenceChanged(new PresenceChangeDto(userId, IsOnline: false, changedAtUtc));
            }
        }

        await base.OnDisconnectedAsync(exception);
    }

    public Task<ReportLocationResult> ReportLocation(ReportLocationRequest request)
    {
        var userId = GetUserId();
        var familyId = GetFamilyIdFromQuery();

        return _reportLocation.Handle(
            new ReportLocationCommand(
                userId,
                familyId,
                request.Latitude,
                request.Longitude,
                request.AccuracyMeters,
                request.BatteryPercent,
                request.RecordedAtUtc),
            Context.ConnectionAborted);
    }

    public static string FamilyGroupName(Guid familyId) => $"family:{familyId}";

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
