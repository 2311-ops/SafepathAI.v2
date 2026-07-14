using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Location;

public record GetLiveLocationsQuery(Guid CallerUserId, Guid FamilyId);

public class GetLiveLocationsQueryHandler : ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>>
{
    private static readonly TimeSpan PingFreshnessWindow = TimeSpan.FromMinutes(2);

    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IPresenceQuery _presence;
    private readonly ISharingAuthorizationService _sharing;
    private readonly ProfileImageUrlFactory? _profileImageUrlFactory;

    public GetLiveLocationsQueryHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IPresenceQuery presence,
        ISharingAuthorizationService sharing,
        ProfileImageUrlFactory? profileImageUrlFactory = null)
    {
        _db = db;
        _authorization = authorization;
        _presence = presence;
        _sharing = sharing;
        _profileImageUrlFactory = profileImageUrlFactory;
    }

    public async Task<IReadOnlyList<MemberLiveLocationDto>> Handle(GetLiveLocationsQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(query.CallerUserId, query.FamilyId, cancellationToken);

        var activeMembers = await (
            from member in _db.FamilyMembers
            join user in _db.Users on member.UserId equals user.Id
            where member.FamilyId == query.FamilyId && member.IsActive
            orderby member.JoinedAt
            select new { member.UserId, user.FullName, user.DisplayName, user.ProfileImagePath, user.ProfileUpdatedAt })
            .ToListAsync(cancellationToken);

        var now = DateTime.UtcNow;
        var results = new List<MemberLiveLocationDto>(activeMembers.Count);

        foreach (var member in activeMembers)
        {
            var latestPing = await _db.LocationPings
                .Where(p => p.UserId == member.UserId)
                .OrderByDescending(p => p.RecordedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            var canViewLocation = await _sharing.CanView(
                query.CallerUserId,
                member.UserId,
                query.FamilyId,
                SharedDataType.LiveLocation,
                cancellationToken);
            var profileImageUrl = canViewLocation && _profileImageUrlFactory is not null
                ? await _profileImageUrlFactory.SignAsync(member.ProfileImagePath, cancellationToken)
                : null;
            var isRecent = canViewLocation && latestPing is not null && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;
            results.Add(new MemberLiveLocationDto(
                member.UserId,
                string.IsNullOrWhiteSpace(member.DisplayName) ? member.FullName : member.DisplayName,
                canViewLocation ? latestPing?.Latitude : null,
                canViewLocation ? latestPing?.Longitude : null,
                canViewLocation ? latestPing?.AccuracyMeters : null,
                canViewLocation ? latestPing?.BatteryPercent : null,
                canViewLocation ? latestPing?.RecordedAtUtc : null,
                _presence.IsOnline(member.UserId) || isRecent,
                profileImageUrl,
                canViewLocation ? member.ProfileUpdatedAt : null));
        }

        return results;
    }
}
