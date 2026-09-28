using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Geofencing;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Geofencing;

public sealed class GeofenceRetentionTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task SweepExpired_RemovesExpiredActivityFeedAndJobsButLeavesZonesAndSos()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        var fixture = await SeedAsync(db, now);

        var deleted = await GeofenceRetentionService.SweepExpired(db, now, CancellationToken.None);

        Assert.Equal(3, deleted);
        Assert.DoesNotContain(db.GeofenceRoutineJobs, job => job.Id == fixture.ExpiredJobId);
        Assert.DoesNotContain(db.GeofenceFeedItems, item => item.Id == fixture.ExpiredFeedItemId);
        Assert.DoesNotContain(db.GeofenceActivities, activity => activity.Id == fixture.ExpiredActivityId);

        Assert.Contains(db.GeofenceActivities, activity => activity.Id == fixture.CutoffActivityId);
        Assert.Contains(db.GeofenceActivities, activity => activity.Id == fixture.FreshActivityId);
        Assert.Contains(db.SafeZones, zone => zone.Id == fixture.SafeZoneId);
        Assert.Contains(db.SosSessions, session => session.Id == fixture.SosSessionId);
        Assert.Contains(db.LocationPings, ping => ping.Id == fixture.LocationPingId);
    }

    [Fact]
    public async Task SweepExpired_IsIdempotent()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        await SeedAsync(db, now);

        var first = await GeofenceRetentionService.SweepExpired(db, now, CancellationToken.None);
        var second = await GeofenceRetentionService.SweepExpired(db, now, CancellationToken.None);

        Assert.Equal(3, first);
        Assert.Equal(0, second);
    }

    private static async Task<Fixture> SeedAsync(ApplicationDbContext db, DateTime now)
    {
        var guardianUserId = Guid.NewGuid();
        var memberUserId = Guid.NewGuid();
        var familyId = Guid.NewGuid();
        var safeZoneId = Guid.NewGuid();
        var expiredActivityId = Guid.NewGuid();
        var cutoffActivityId = Guid.NewGuid();
        var freshActivityId = Guid.NewGuid();
        var expiredFeedItemId = Guid.NewGuid();
        var expiredJobId = Guid.NewGuid();
        var sosSessionId = Guid.NewGuid();
        var locationPingId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = guardianUserId, Email = $"guardian-{guardianUserId:N}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberUserId, Email = $"member-{memberUserId:N}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = now });
        db.Families.Add(new Family { Id = familyId, Name = "Retention", CreatedByUserId = guardianUserId, CreatedAt = now });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = guardianUserId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            IsActive = true,
            JoinedAt = now,
        });
        db.SafeZones.Add(new SafeZone
        {
            Id = safeZoneId,
            FamilyId = familyId,
            AssignedMemberUserId = memberUserId,
            CreatedByUserId = guardianUserId,
            Category = SafeZoneCategory.Home,
            Latitude = 30,
            Longitude = 31,
            RadiusMeters = 120,
            Sensitivity = SafeZoneSensitivity.Balanced,
            CreatedAtUtc = now,
            IsActive = true,
        });
        db.GeofenceActivities.AddRange(
            Activity(expiredActivityId, safeZoneId, memberUserId, now.AddDays(-8), now.AddTicks(-1)),
            Activity(cutoffActivityId, safeZoneId, memberUserId, now.AddDays(-7), now),
            Activity(freshActivityId, safeZoneId, memberUserId, now.AddMinutes(-1), now.AddDays(7)));
        db.GeofenceFeedItems.Add(new GeofenceFeedItem
        {
            Id = expiredFeedItemId,
            ActivityId = expiredActivityId,
            RecipientUserId = guardianUserId,
            CreatedAtUtc = now.AddDays(-8),
            ExpiresAtUtc = now.AddTicks(-1),
        });
        db.GeofenceRoutineJobs.Add(new GeofenceRoutineJob
        {
            Id = expiredJobId,
            FeedItemId = expiredFeedItemId,
            RecipientUserId = guardianUserId,
            State = GeofenceRoutineJobState.Expired,
            CreatedAtUtc = now.AddDays(-8),
            NextAttemptAtUtc = now.AddDays(-8),
            ExpiresAtUtc = now.AddTicks(-1),
        });
        db.SosSessions.Add(new SosSession
        {
            Id = sosSessionId,
            FamilyId = familyId,
            TriggeredByUserId = memberUserId,
            Status = SosSessionStatus.Active,
            TriggeredAtUtc = now.AddDays(-30),
            ReceivedAtUtc = now.AddDays(-30),
        });
        db.LocationPings.Add(new LocationPing
        {
            Id = locationPingId,
            UserId = memberUserId,
            Latitude = 30,
            Longitude = 31,
            AccuracyMeters = 20,
            RecordedAtUtc = now.AddDays(-30),
            ReceivedAtUtc = now.AddDays(-30),
        });
        await db.SaveChangesAsync();

        return new Fixture(expiredActivityId, cutoffActivityId, freshActivityId, expiredFeedItemId, expiredJobId, safeZoneId, sosSessionId, locationPingId);
    }

    private static GeofenceActivity Activity(Guid id, Guid safeZoneId, Guid memberUserId, DateTime occurredAtUtc, DateTime retainUntilUtc) => new()
    {
        Id = id,
        SafeZoneId = safeZoneId,
        SafeZoneDisplayName = "Home",
        MemberUserId = memberUserId,
        Transition = GeofenceTransition.Enter,
        OccurredAtUtc = occurredAtUtc,
        RecordedAtUtc = occurredAtUtc,
        RetainUntilUtc = retainUntilUtc,
    };

    private sealed record Fixture(
        Guid ExpiredActivityId,
        Guid CutoffActivityId,
        Guid FreshActivityId,
        Guid ExpiredFeedItemId,
        Guid ExpiredJobId,
        Guid SafeZoneId,
        Guid SosSessionId,
        Guid LocationPingId);

    public void Dispose() => _factory.Dispose();
}
