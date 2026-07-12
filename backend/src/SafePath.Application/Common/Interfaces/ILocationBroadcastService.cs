using SafePath.Application.Location;

namespace SafePath.Application.Common.Interfaces;

public interface ILocationBroadcastService
{
    Task BroadcastLocation(
        Guid familyId,
        LocationUpdateDto update,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default);

    Task BroadcastPresence(
        Guid familyId,
        PresenceChangeDto change,
        CancellationToken cancellationToken = default);
}
