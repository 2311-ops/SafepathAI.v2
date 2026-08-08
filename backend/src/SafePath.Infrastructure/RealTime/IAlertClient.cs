using SafePath.Application.Sos;

namespace SafePath.Infrastructure.RealTime;

/// <summary>
/// Strongly-typed client contract for <see cref="AlertHub"/> — the dedicated emergency channel,
/// structurally separate from <see cref="ILocationClient"/>. <see cref="LiveLocationWindowUpdate"/>
/// is declared now so the contract is stable, but is only populated starting in plan 03-08.
/// </summary>
public interface IAlertClient
{
    Task SosTriggered(SosSessionDto session);

    Task DeliveryStatusChanged(SosDeliveryStatusChangedDto update);

    Task SosCanceled(SosCanceledDto canceled);

    Task LiveLocationWindowUpdate(SosLocationUpdateDto update);
}
