using SafePath.Domain.Enums;

namespace SafePath.Application.Common.Interfaces;

public interface ISharingAuthorizationService
{
    Task<IReadOnlyCollection<Guid>> FilterRecipients(
        Guid ownerUserId,
        Guid familyId,
        SharedDataType dataType,
        IReadOnlyCollection<Guid> candidateRecipientUserIds,
        CancellationToken cancellationToken = default);

    Task<bool> CanView(
        Guid viewerUserId,
        Guid ownerUserId,
        Guid familyId,
        SharedDataType dataType,
        CancellationToken cancellationToken = default);
}
