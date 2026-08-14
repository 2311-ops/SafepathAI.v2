using SafePath.Application.Geofencing;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Geofencing;

public sealed class SubmitGeofenceEvidenceTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Confirmation_WritesActivityFeedAndRoutineJobsExactlyOnce()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new SubmitGeofenceEvidenceCommandHandler(db, new FamilyAuthorizationService(db));
        var firstEventId = Guid.NewGuid();

        var waiting = await handler.Handle(Command(fixture, firstEventId, fixture.Now));
        var confirmed = await handler.Handle(Command(fixture, Guid.NewGuid(), fixture.Now.AddSeconds(60)));
        var replay = await handler.Handle(Command(fixture, firstEventId, fixture.Now));

        Assert.Equal(GeofenceEvidenceOutcome.Waiting, waiting.Outcome);
        Assert.Equal(GeofenceEvidenceOutcome.Confirmed, confirmed.Outcome);
        Assert.Equal(GeofenceEvidenceOutcome.Duplicate, replay.Outcome);
        Assert.Single(db.GeofenceActivities);
        Assert.Equal(2, db.GeofenceFeedItems.Count());
        Assert.Equal(2, db.GeofenceRoutineJobs.Count());
    }

    [Fact]
    public async Task AmbiguousOrOppositeEvidence_DoesNotCreateDeliveryRows()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new SubmitGeofenceEvidenceCommandHandler(db, new FamilyAuthorizationService(db));

        var waiting = await handler.Handle(Command(fixture, Guid.NewGuid(), fixture.Now, latitude: 0.00075, accuracyMeters: 20));
        var reset = await handler.Handle(Command(fixture, Guid.NewGuid(), fixture.Now.AddSeconds(10), latitude: 0.002));
        var restarted = await handler.Handle(Command(fixture, Guid.NewGuid(), fixture.Now.AddSeconds(60)));

        Assert.Equal(GeofenceEvidenceOutcome.Waiting, waiting.Outcome);
        Assert.Equal(GeofenceEvidenceOutcome.Reset, reset.Outcome);
        Assert.Equal(GeofenceEvidenceOutcome.Waiting, restarted.Outcome);
        Assert.Empty(db.GeofenceActivities);
        Assert.Empty(db.GeofenceFeedItems);
        Assert.Empty(db.GeofenceRoutineJobs);
    }

    [Fact]
    public async Task CallerMustBeAssignedActiveMemberAndEvidenceMustBeValid()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new SubmitGeofenceEvidenceCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(Command(fixture, Guid.NewGuid(), fixture.Now, callerUserId: fixture.GuardianUserId)));
        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(Command(fixture, Guid.Empty, fixture.Now)));

        Assert.Empty(db.GeofenceCandidates);
    }

    private static SubmitGeofenceEvidenceCommand Command(
        Fixture fixture,
        Guid eventId,
        DateTime occurredAtUtc,
        double latitude = 0.0002,
        double accuracyMeters = 5,
        Guid? callerUserId = null) =>
        new(callerUserId ?? fixture.MemberUserId, eventId, fixture.ZoneId, 1, GeofenceTransition.Enter,
            occurredAtUtc, latitude, 0, accuracyMeters);

    private static async Task<Fixture> SeedAsync(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var secondGuardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        var zoneId = Guid.NewGuid();
        var now = DateTime.UtcNow.AddSeconds(-61);
        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = now },
            new User { Id = secondGuardianId, Email = $"guardian-{secondGuardianId}@example.com", FullName = "Guardian two", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberId, Email = $"member-{memberId}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = now });
        db.Families.Add(new Family { Id = familyId, Name = "Confirmation", CreatedByUserId = guardianId, CreatedAt = now });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = now, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = secondGuardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = now, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = now, IsActive = true });
        db.SafeZones.Add(new SafeZone { Id = zoneId, FamilyId = familyId, AssignedMemberUserId = memberId, CreatedByUserId = guardianId, Category = SafeZoneCategory.Home, Latitude = 0, Longitude = 0, RadiusMeters = 100, Sensitivity = SafeZoneSensitivity.Balanced, NotifyAssignedMember = false, CreatedAtUtc = now });
        db.SafeZoneRecipients.AddRange(
            new SafeZoneRecipient { SafeZoneId = zoneId, RecipientUserId = guardianId },
            new SafeZoneRecipient { SafeZoneId = zoneId, RecipientUserId = secondGuardianId });
        db.SafeZoneRegistrations.Add(new SafeZoneRegistration { Id = Guid.NewGuid(), SafeZoneId = zoneId, MemberUserId = memberId, Generation = 1, IssuedAtUtc = now });
        await db.SaveChangesAsync();
        return new Fixture(zoneId, guardianId, memberId, now);
    }

    private sealed record Fixture(Guid ZoneId, Guid GuardianUserId, Guid MemberUserId, DateTime Now);

    public void Dispose() => _factory.Dispose();
}
