using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

/// <summary>
/// Guardian-only geofence history. Dates are UTC so clients can localize the exact timestamps
/// without the server silently applying the guardian's current device time zone.
/// </summary>
public sealed record GetGeofenceActivityQuery(
    Guid CallerUserId,
    Guid FamilyId,
    Guid? MemberUserId = null,
    Guid? ZoneId = null,
    GeofenceTransition? Transition = null,
    DateTime? FromUtc = null,
    DateTime? ToUtc = null);

public sealed record GeofenceActivityDto(
    Guid? VisitId,
    Guid MemberUserId,
    string MemberDisplayName,
    Guid? SafeZoneId,
    string SafeZoneDisplayName,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    DateTime? EnteredAtUtc,
    DateTime? ExitedAtUtc,
    int? CompletedVisitDurationSeconds,
    bool IsInProgress);

public sealed class GetGeofenceActivityQueryHandler : ICommandHandler<GetGeofenceActivityQuery, IReadOnlyList<GeofenceActivityDto>>
{
    private static readonly TimeSpan RetentionPeriod = TimeSpan.FromDays(7);

    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public GetGeofenceActivityQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<IReadOnlyList<GeofenceActivityDto>> Handle(GetGeofenceActivityQuery query, CancellationToken cancellationToken = default)
    {
        Validate(query);
        await _authorization.RequireRole(query.CallerUserId, query.FamilyId, Role.Guardian, cancellationToken);

        var familyMemberIds = await _db.FamilyMembers
            .Where(member => member.FamilyId == query.FamilyId && member.IsActive)
            .Select(member => member.UserId)
            .ToListAsync(cancellationToken);

        if (query.MemberUserId is { } memberUserId && !familyMemberIds.Contains(memberUserId))
        {
            throw new ArgumentException("The requested member is not active in this family.", nameof(query));
        }

        if (query.ZoneId is { } zoneId && !await _db.SafeZones.AnyAsync(zone => zone.Id == zoneId && zone.FamilyId == query.FamilyId, cancellationToken))
        {
            throw new ArgumentException("The requested zone does not belong to this family.", nameof(query));
        }

        var nowUtc = DateTime.UtcNow;
        var cutoffUtc = nowUtc.Subtract(RetentionPeriod);
        var fromUtc = query.FromUtc is { } requestedFrom ? Max(requestedFrom, cutoffUtc) : cutoffUtc;
        var toUtc = query.ToUtc is { } requestedTo ? Min(requestedTo, nowUtc) : nowUtc;
        if (fromUtc > toUtc)
        {
            return [];
        }

        var rows = await _db.GeofenceActivities
            .Where(activity => familyMemberIds.Contains(activity.MemberUserId) &&
                activity.RetainUntilUtc > nowUtc &&
                activity.OccurredAtUtc >= fromUtc && activity.OccurredAtUtc <= toUtc &&
                (query.MemberUserId == null || activity.MemberUserId == query.MemberUserId) &&
                (query.ZoneId == null || activity.SafeZoneId == query.ZoneId))
            .Join(_db.Users,
                activity => activity.MemberUserId,
                user => user.Id,
                (activity, user) => new { Activity = activity, user.FullName })
            .OrderBy(item => item.Activity.OccurredAtUtc)
            .ThenBy(item => item.Activity.Id)
            .ToListAsync(cancellationToken);

        var records = rows
            .Select(row => new ActivityWithMember(row.Activity, row.FullName))
            .ToArray();

        return Pair(records)
            .Where(item => query.Transition == null || item.Transition == query.Transition)
            .OrderByDescending(item => item.OccurredAtUtc)
            .ToArray();
    }

    private static IReadOnlyList<GeofenceActivityDto> Pair(IReadOnlyList<ActivityWithMember> records)
    {
        var output = new List<GeofenceActivityDto>();
        var openEntries = new List<ActivityWithMember>();

        foreach (var record in records)
        {
            if (record.Activity.Transition == GeofenceTransition.Enter)
            {
                openEntries.Add(record);
                continue;
            }

            var entryIndex = FindMatchingEntry(openEntries, record.Activity);
            if (entryIndex < 0)
            {
                output.Add(ToUnmatchedExit(record));
                continue;
            }

            var entry = openEntries[entryIndex];
            openEntries.RemoveAt(entryIndex);
            output.Add(ToPairedVisit(entry, record));
        }

        output.AddRange(openEntries.Select(ToInProgress));
        return output;
    }

    private static int FindMatchingEntry(IReadOnlyList<ActivityWithMember> openEntries, GeofenceActivity exit)
    {
        for (var index = 0; index < openEntries.Count; index++)
        {
            var entry = openEntries[index].Activity;
            if (entry.MemberUserId != exit.MemberUserId || entry.SafeZoneId != exit.SafeZoneId)
            {
                continue;
            }

            if (entry.VisitId == exit.VisitId && entry.VisitId is not null)
            {
                return index;
            }

            if (entry.VisitId is null && exit.VisitId is null)
            {
                return index;
            }
        }

        return -1;
    }

    private static GeofenceActivityDto ToPairedVisit(ActivityWithMember entry, ActivityWithMember exit)
    {
        var duration = exit.Activity.CompletedVisitDurationSeconds ??
            Math.Max(0, (int)(exit.Activity.OccurredAtUtc - entry.Activity.OccurredAtUtc).TotalSeconds);
        return new GeofenceActivityDto(
            exit.Activity.VisitId ?? entry.Activity.VisitId,
            entry.Activity.MemberUserId,
            entry.MemberDisplayName,
            entry.Activity.SafeZoneId,
            entry.Activity.SafeZoneDisplayName,
            GeofenceTransition.Enter,
            exit.Activity.OccurredAtUtc,
            entry.Activity.OccurredAtUtc,
            exit.Activity.OccurredAtUtc,
            duration,
            false);
    }

    private static GeofenceActivityDto ToInProgress(ActivityWithMember entry) => new(
        entry.Activity.VisitId,
        entry.Activity.MemberUserId,
        entry.MemberDisplayName,
        entry.Activity.SafeZoneId,
        entry.Activity.SafeZoneDisplayName,
        GeofenceTransition.Enter,
        entry.Activity.OccurredAtUtc,
        entry.Activity.OccurredAtUtc,
        null,
        null,
        true);

    private static GeofenceActivityDto ToUnmatchedExit(ActivityWithMember exit) => new(
        exit.Activity.VisitId,
        exit.Activity.MemberUserId,
        exit.MemberDisplayName,
        exit.Activity.SafeZoneId,
        exit.Activity.SafeZoneDisplayName,
        GeofenceTransition.Exit,
        exit.Activity.OccurredAtUtc,
        null,
        exit.Activity.OccurredAtUtc,
        null,
        false);

    private static DateTime Max(DateTime left, DateTime right) => left > right ? left : right;
    private static DateTime Min(DateTime left, DateTime right) => left < right ? left : right;

    private static void Validate(GetGeofenceActivityQuery query)
    {
        if (query.CallerUserId == Guid.Empty || query.FamilyId == Guid.Empty ||
            query.FromUtc is { Kind: not DateTimeKind.Utc } || query.ToUtc is { Kind: not DateTimeKind.Utc })
        {
            throw new ArgumentException("Activity query fields are invalid.", nameof(query));
        }
    }

    private sealed record ActivityWithMember(GeofenceActivity Activity, string MemberDisplayName);
}
