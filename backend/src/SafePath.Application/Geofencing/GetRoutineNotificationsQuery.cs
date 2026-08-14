using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

/// <summary>Returns only the authenticated recipient's durable routine-notification feed.</summary>
public sealed record GetRoutineNotificationsQuery(Guid RecipientUserId);

public sealed record RoutineNotificationDto(
    Guid Id,
    Guid ActivityId,
    Guid MemberUserId,
    string ZoneName,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    DateTime CreatedAtUtc,
    bool IsRead);

public sealed class GetRoutineNotificationsQueryHandler
    : ICommandHandler<GetRoutineNotificationsQuery, IReadOnlyList<RoutineNotificationDto>>
{
    private readonly IApplicationDbContext _db;

    public GetRoutineNotificationsQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<IReadOnlyList<RoutineNotificationDto>> Handle(
        GetRoutineNotificationsQuery query,
        CancellationToken cancellationToken = default)
    {
        if (query.RecipientUserId == Guid.Empty)
            throw new ArgumentException("Recipient is required.", nameof(query));

        var nowUtc = DateTime.UtcNow;
        return await _db.GeofenceFeedItems
            .AsNoTracking()
            .Where(item => item.RecipientUserId == query.RecipientUserId && item.ExpiresAtUtc >= nowUtc)
            .Join(
                _db.GeofenceActivities.AsNoTracking(),
                item => item.ActivityId,
                activity => activity.Id,
                (item, activity) => new { item, activity })
            .OrderByDescending(item => item.activity.OccurredAtUtc)
            .Select(item => new RoutineNotificationDto(
                item.item.Id,
                item.item.ActivityId,
                item.activity.MemberUserId,
                item.activity.SafeZoneDisplayName,
                item.activity.Transition,
                item.activity.OccurredAtUtc,
                item.item.CreatedAtUtc,
                item.item.ReadAtUtc != null))
            .ToListAsync(cancellationToken);
    }
}
