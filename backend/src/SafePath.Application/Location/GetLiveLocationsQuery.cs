using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Location;

public record GetLiveLocationsQuery(Guid CallerUserId, Guid FamilyId);

public class GetLiveLocationsQueryHandler : ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>>
{
    private static readonly TimeSpan PingFreshnessWindow = TimeSpan.FromMinutes(2);

    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IPresenceQuery _presence;

    public GetLiveLocationsQueryHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IPresenceQuery presence)
    {
        _db = db;
        _authorization = authorization;
        _presence = presence;
    }

    public async Task<IReadOnlyList<MemberLiveLocationDto>> Handle(GetLiveLocationsQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(query.CallerUserId, query.FamilyId, cancellationToken);

        var activeMembers = await (
            from member in _db.FamilyMembers
            join user in _db.Users on member.UserId equals user.Id
            where member.FamilyId == query.FamilyId && member.IsActive
            orderby member.JoinedAt
            select new { member.UserId, user.FullName })
            .ToListAsync(cancellationToken);

        var now = DateTime.UtcNow;
        var results = new List<MemberLiveLocationDto>(activeMembers.Count);

        foreach (var member in activeMembers)
        {
            var latestPing = await _db.LocationPings
                .Where(p => p.UserId == member.UserId)
                .OrderByDescending(p => p.RecordedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            var isRecent = latestPing is not null && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;
            results.Add(new MemberLiveLocationDto(
                member.UserId,
                member.FullName,
                latestPing?.Latitude,
                latestPing?.Longitude,
                latestPing?.AccuracyMeters,
                latestPing?.BatteryPercent,
                latestPing?.RecordedAtUtc,
                _presence.IsOnline(member.UserId) || isRecent));
        }

        return results;
    }
}
