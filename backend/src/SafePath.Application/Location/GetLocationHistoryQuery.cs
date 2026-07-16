using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Location;

public record GetLocationHistoryQuery(
    Guid CallerUserId,
    Guid FamilyId,
    Guid TargetUserId,
    DateTime FromUtc,
    DateTime ToUtc);

public class GetLocationHistoryQueryHandler : ICommandHandler<GetLocationHistoryQuery, LocationHistoryDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly ISharingAuthorizationService _sharing;

    public GetLocationHistoryQueryHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        ISharingAuthorizationService sharing)
    {
        _db = db;
        _authorization = authorization;
        _sharing = sharing;
    }

    public async Task<LocationHistoryDto> Handle(
        GetLocationHistoryQuery query,
        CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(query.CallerUserId, query.FamilyId, cancellationToken);
        await RequireTargetInFamily(query.TargetUserId, query.FamilyId, cancellationToken);

        if (query.CallerUserId != query.TargetUserId)
        {
            var canViewHistory = await _sharing.CanView(
                query.CallerUserId,
                query.TargetUserId,
                query.FamilyId,
                SharedDataType.History,
                cancellationToken);
            if (!canViewHistory)
            {
                throw new FamilyAuthorizationDeniedException(
                    $"User {query.CallerUserId} cannot view history for user {query.TargetUserId} in family {query.FamilyId}.");
            }
        }

        var pings = await _db.LocationPings
            .Where(p =>
                p.UserId == query.TargetUserId &&
                p.RecordedAtUtc >= query.FromUtc &&
                p.RecordedAtUtc <= query.ToUtc)
            .OrderBy(p => p.RecordedAtUtc)
            .ToListAsync(cancellationToken);

        var points = pings
            .Select(p => new LocationHistoryPointDto(p.Latitude, p.Longitude, p.RecordedAtUtc))
            .ToList();

        return new LocationHistoryDto(points, StopDetection.DetectStops(pings));
    }

    private async Task RequireTargetInFamily(Guid targetUserId, Guid familyId, CancellationToken cancellationToken)
    {
        var targetExists = await _db.FamilyMembers.AnyAsync(
            m => m.FamilyId == familyId && m.UserId == targetUserId && m.IsActive,
            cancellationToken);

        if (!targetExists)
        {
            throw new FamilyAuthorizationDeniedException(
                $"User {targetUserId} is not an active member of family {familyId}.");
        }
    }
}
