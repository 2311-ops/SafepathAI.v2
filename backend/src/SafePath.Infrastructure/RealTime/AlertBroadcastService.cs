using Microsoft.AspNetCore.SignalR;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

namespace SafePath.Infrastructure.RealTime;

/// <summary>
/// Dedicated SOS-only broadcast implementation over <see cref="AlertHub"/>/<see cref="IAlertClient"/>.
/// Deliberately not folded into a shared/generic notification service — a future inactivity or
/// geofence alert must never be able to change or slow this code path (Core Value).
/// </summary>
public class AlertBroadcastService : IAlertBroadcastService
{
    private readonly IHubContext<AlertHub, IAlertClient> _hubContext;

    public AlertBroadcastService(IHubContext<AlertHub, IAlertClient> hubContext)
    {
        _hubContext = hubContext;
    }

    public Task SosTriggered(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosSessionDto session,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Users(recipientUserIds.Select(id => id.ToString())).SosTriggered(session);

    public Task DeliveryStatusChanged(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosDeliveryStatusChangedDto update,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Users(recipientUserIds.Select(id => id.ToString())).DeliveryStatusChanged(update);

    public Task SosCanceled(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosCanceledDto canceled,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Users(recipientUserIds.Select(id => id.ToString())).SosCanceled(canceled);

    public Task LiveLocationWindowUpdate(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosLocationUpdateDto update,
        CancellationToken cancellationToken = default) =>
        _hubContext.Clients.Users(recipientUserIds.Select(id => id.ToString())).LiveLocationWindowUpdate(update);
}
