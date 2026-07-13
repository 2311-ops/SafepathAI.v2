using Microsoft.AspNetCore.SignalR;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;

namespace SafePath.Infrastructure.RealTime;

public class LocationBroadcastService : ILocationBroadcastService
{
    private readonly IHubContext<LocationHub, ILocationClient> _hubContext;

    public LocationBroadcastService(IHubContext<LocationHub, ILocationClient> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task BroadcastLocation(
        Guid familyId,
        LocationUpdateDto update,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        var userIds = eligibleRecipientUserIds.Select(userId => userId.ToString());
        return _hubContext.Clients.Users(userIds).LocationUpdated(update);
    }

    public Task BroadcastPresence(
        Guid familyId,
        PresenceChangeDto change,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Group(LocationHub.FamilyGroupName(familyId)).PresenceChanged(change);

    public Task BroadcastLowBattery(
        Guid familyId,
        LowBatteryAlertDto alert,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        var userIds = eligibleRecipientUserIds.Select(userId => userId.ToString());
        return _hubContext.Clients.Users(userIds).LowBattery(alert);
    }

    public Task BroadcastProfileUpdated(
        Guid familyId,
        ProfileUpdateDto update,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Group(LocationHub.FamilyGroupName(familyId)).ProfileUpdated(update);
}
