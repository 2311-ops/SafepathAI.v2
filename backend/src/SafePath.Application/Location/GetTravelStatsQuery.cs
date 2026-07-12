using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Location;

public record GetTravelStatsQuery(
    Guid CallerUserId,
    Guid FamilyId,
    Guid TargetUserId,
    DateTime FromUtc,
    DateTime ToUtc);

public class GetTravelStatsQueryHandler : ICommandHandler<GetTravelStatsQuery, TravelStatsDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly ISharingAuthorizationService _sharing;

    public GetTravelStatsQueryHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        ISharingAuthorizationService sharing)
    {
        _db = db;
        _authorization = authorization;
        _sharing = sharing;
    }

    public async Task<TravelStatsDto> Handle(
        GetTravelStatsQuery query,
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
                    $"User {query.CallerUserId} cannot view travel stats for user {query.TargetUserId} in family {query.FamilyId}.");
            }
        }

        var pings = await _db.LocationPings
            .Where(p =>
                p.UserId == query.TargetUserId &&
                p.RecordedAtUtc >= query.FromUtc &&
                p.RecordedAtUtc <= query.ToUtc)
            .OrderBy(p => p.RecordedAtUtc)
            .ToListAsync(cancellationToken);

        if (pings.Count == 0)
        {
            return new TravelStatsDto(0, TimeSpan.Zero, 0);
        }

        var totalDistance = TotalDistanceMeters(pings);
        var timeAway = pings[^1].RecordedAtUtc - pings[0].RecordedAtUtc;
        var stopCount = StopDetection.DetectStops(pings).Count;

        return new TravelStatsDto(totalDistance, timeAway, stopCount);
    }

    private static double TotalDistanceMeters(IReadOnlyList<LocationPing> pings)
    {
        var total = 0d;
        for (var i = 1; i < pings.Count; i++)
        {
            var previous = pings[i - 1];
            var current = pings[i];
            total += GeoMath.HaversineMeters(
                previous.Latitude,
                previous.Longitude,
                current.Latitude,
                current.Longitude);
        }

        return total;
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
