using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

public interface ILocationClient
{
    Task LocationUpdated(LocationUpdateDto update);

    Task PresenceChanged(PresenceChangeDto change);
}
