using SafePath.Application.Geofencing;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Geofencing;

public sealed class GeofenceActivityQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task ReturnsNewestFirstPairedAndUnmatchedRowsWithExactUtcTimes()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new GetGeofenceActivityQueryHandler(db, new FamilyAuthorizationService(db));

        var activity = await handler.Handle(new GetGeofenceActivityQuery(fixture.GuardianUserId, fixture.FamilyId));

        Assert.Equal(3, activity.Count);
        var paired = Assert.Single(activity, item => item.VisitId == fixture.PairedVisitId);
        Assert.Equal(fixture.MemberUserId, paired.MemberUserId);
        Assert.Equal("Alex", paired.MemberDisplayName);
        Assert.Equal(fixture.HomeZoneId, paired.SafeZoneId);
        Assert.Equal("Home", paired.SafeZoneDisplayName);
        Assert.Equal(GeofenceTransition.Enter, paired.Transition);
        Assert.Equal(fixture.EnteredAtUtc, paired.EnteredAtUtc);
        Assert.Equal(fixture.ExitedAtUtc, paired.ExitedAtUtc);
        Assert.Equal(300, paired.CompletedVisitDurationSeconds);
        Assert.False(paired.IsInProgress);

        var inProgress = Assert.Single(activity, item => item.VisitId == fixture.InProgressVisitId);
        Assert.Equal(fixture.InProgressEnteredAtUtc, inProgress.EnteredAtUtc);
        Assert.Null(inProgress.ExitedAtUtc);
        Assert.Null(inProgress.CompletedVisitDurationSeconds);
        Assert.True(inProgress.IsInProgress);

        var unmatchedExit = Assert.Single(activity, item => item.VisitId == fixture.UnmatchedExitVisitId);
        Assert.Equal(GeofenceTransition.Exit, unmatchedExit.Transition);
        Assert.Null(unmatchedExit.EnteredAtUtc);
        Assert.Equal(fixture.UnmatchedExitAtUtc, unmatchedExit.ExitedAtUtc);
        Assert.Null(unmatchedExit.CompletedVisitDurationSeconds);
        Assert.False(unmatchedExit.IsInProgress);
        Assert.True(activity.SequenceEqual(activity.OrderByDescending(item => item.OccurredAtUtc)));
    }

    [Fact]
    public async Task ComposesFiltersAndRescopesMemberAndZoneToTheAuthorizedFamily()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new GetGeofenceActivityQueryHandler(db, new FamilyAuthorizationService(db));

        var filtered = await handler.Handle(new GetGeofenceActivityQuery(
            fixture.GuardianUserId,
            fixture.FamilyId,
            fixture.MemberUserId,
            fixture.HomeZoneId,
            GeofenceTransition.Enter,
            fixture.EnteredAtUtc.AddMinutes(-1),
            fixture.ExitedAtUtc.AddMinutes(1)));

        var result = Assert.Single(filtered);
        Assert.Equal(fixture.PairedVisitId, result.VisitId);

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new GetGeofenceActivityQuery(
            fixture.GuardianUserId, fixture.FamilyId, fixture.OtherFamilyMemberUserId)));
        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new GetGeofenceActivityQuery(
            fixture.GuardianUserId, fixture.FamilyId, null, fixture.OtherFamilyZoneId)));
        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetGeofenceActivityQuery(
            fixture.MemberUserId, fixture.FamilyId)));
    }

    private static async Task<Fixture> SeedAsync(ApplicationDbContext db)
    {
        var now = DateTime.UtcNow;
        var familyId = Guid.NewGuid();
        var otherFamilyId = Guid.NewGuid();
        var guardianUserId = Guid.NewGuid();
        var memberUserId = Guid.NewGuid();
        var otherFamilyMemberUserId = Guid.NewGuid();
        var homeZoneId = Guid.NewGuid();
        var otherFamilyZoneId = Guid.NewGuid();
        var pairedVisitId = Guid.NewGuid();
        var inProgressVisitId = Guid.NewGuid();
        var unmatchedExitVisitId = Guid.NewGuid();
        var enteredAtUtc = now.AddMinutes(-30);
        var exitedAtUtc = now.AddMinutes(-25);
        var inProgressEnteredAtUtc = now.AddMinutes(-10);
        var unmatchedExitAtUtc = now.AddMinutes(-5);

        db.Users.AddRange(
            new User { Id = guardianUserId, Email = $"guardian-{guardianUserId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberUserId, Email = $"member-{memberUserId}@example.com", FullName = "Alex", Role = Role.Member, CreatedAt = now },
            new User { Id = otherFamilyMemberUserId, Email = $"other-{otherFamilyMemberUserId}@example.com", FullName = "Other", Role = Role.Member, CreatedAt = now });
        db.Families.AddRange(
            new Family { Id = familyId, Name = "Primary", CreatedByUserId = guardianUserId, CreatedAt = now },
            new Family { Id = otherFamilyId, Name = "Other", CreatedByUserId = guardianUserId, CreatedAt = now });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianUserId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, IsActive = true, JoinedAt = now },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberUserId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, IsActive = true, JoinedAt = now },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = otherFamilyId, UserId = otherFamilyMemberUserId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, IsActive = true, JoinedAt = now });
        db.SafeZones.AddRange(
            Zone(homeZoneId, familyId, memberUserId, guardianUserId, "Home", now),
            Zone(otherFamilyZoneId, otherFamilyId, otherFamilyMemberUserId, guardianUserId, "Other", now));
        db.GeofenceActivities.AddRange(
            Activity(homeZoneId, "Home", memberUserId, GeofenceTransition.Enter, pairedVisitId, enteredAtUtc, now.AddDays(7)),
            Activity(homeZoneId, "Home", memberUserId, GeofenceTransition.Exit, pairedVisitId, exitedAtUtc, now.AddDays(7), 300),
            Activity(homeZoneId, "Home", memberUserId, GeofenceTransition.Enter, inProgressVisitId, inProgressEnteredAtUtc, now.AddDays(7)),
            Activity(homeZoneId, "Home", memberUserId, GeofenceTransition.Exit, unmatchedExitVisitId, unmatchedExitAtUtc, now.AddDays(7)),
            Activity(homeZoneId, "Home", memberUserId, GeofenceTransition.Enter, Guid.NewGuid(), now.AddDays(-8), now.AddSeconds(-1)),
            Activity(otherFamilyZoneId, "Other", otherFamilyMemberUserId, GeofenceTransition.Enter, Guid.NewGuid(), now.AddMinutes(-1), now.AddDays(7)));
        await db.SaveChangesAsync();

        return new Fixture(familyId, guardianUserId, memberUserId, otherFamilyMemberUserId, homeZoneId, otherFamilyZoneId,
            pairedVisitId, inProgressVisitId, unmatchedExitVisitId, enteredAtUtc, exitedAtUtc, inProgressEnteredAtUtc, unmatchedExitAtUtc);
    }

    private static SafeZone Zone(Guid id, Guid familyId, Guid memberUserId, Guid creatorUserId, string customName, DateTime now) => new()
    {
        Id = id, FamilyId = familyId, AssignedMemberUserId = memberUserId, CreatedByUserId = creatorUserId,
        Category = SafeZoneCategory.Custom, CustomName = customName, Latitude = 30, Longitude = 31, RadiusMeters = 100,
        Sensitivity = SafeZoneSensitivity.Balanced, CreatedAtUtc = now
    };

    private static GeofenceActivity Activity(Guid zoneId, string zoneName, Guid memberUserId, GeofenceTransition transition,
        Guid visitId, DateTime occurredAtUtc, DateTime retainUntilUtc, int? durationSeconds = null) => new()
    {
        Id = Guid.NewGuid(), SafeZoneId = zoneId, SafeZoneDisplayName = zoneName, MemberUserId = memberUserId,
        Transition = transition, VisitId = visitId, OccurredAtUtc = occurredAtUtc, RecordedAtUtc = occurredAtUtc,
        RetainUntilUtc = retainUntilUtc, CompletedVisitDurationSeconds = durationSeconds
    };

    private sealed record Fixture(Guid FamilyId, Guid GuardianUserId, Guid MemberUserId, Guid OtherFamilyMemberUserId,
        Guid HomeZoneId, Guid OtherFamilyZoneId, Guid PairedVisitId, Guid InProgressVisitId, Guid UnmatchedExitVisitId,
        DateTime EnteredAtUtc, DateTime ExitedAtUtc, DateTime InProgressEnteredAtUtc, DateTime UnmatchedExitAtUtc);

    public void Dispose() => _factory.Dispose();
}
