using SafePath.Application.Sos;

namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Fan-out contract for the dedicated SOS alert channel. Kept in the Application layer — no
/// SignalR type (e.g. IHubContext) may ever appear here — so Application code never depends on
/// Infrastructure, preserving the Clean Architecture boundary. Implemented by
/// SafePath.Infrastructure.RealTime.AlertBroadcastService, a dedicated service separate from
/// ILocationBroadcastService so a future routine notification can never slow this path down.
/// </summary>
public interface IAlertBroadcastService
{
    Task SosTriggered(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosSessionDto session,
        CancellationToken cancellationToken = default);

    Task DeliveryStatusChanged(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosDeliveryStatusChangedDto update,
        CancellationToken cancellationToken = default);

    Task SosCanceled(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosCanceledDto canceled,
        CancellationToken cancellationToken = default);

    Task LiveLocationWindowUpdate(
        Guid familyId,
        IEnumerable<Guid> recipientUserIds,
        SosLocationUpdateDto update,
        CancellationToken cancellationToken = default);
}
