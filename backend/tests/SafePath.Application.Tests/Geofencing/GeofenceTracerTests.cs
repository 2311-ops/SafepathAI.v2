using SafePath.Application.Geofencing;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Geofencing;

public sealed class GeofenceTracerTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Acknowledgement_MustMatchAssignedMemberZoneAndGeneration()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new AcknowledgeSafeZoneRegistrationCommandHandler(db, new FamilyAuthorizationService(db));

        var wrongMember = await handler.Handle(new AcknowledgeSafeZoneRegistrationCommand(fixture.GuardianUserId, fixture.ZoneId, 1));
        var wrongGeneration = await handler.Handle(new AcknowledgeSafeZoneRegistrationCommand(fixture.MemberUserId, fixture.ZoneId, 2));
        var accepted = await handler.Handle(new AcknowledgeSafeZoneRegistrationCommand(fixture.MemberUserId, fixture.ZoneId, 1));

        Assert.False(wrongMember);
        Assert.False(wrongGeneration);
        Assert.True(accepted);
        Assert.NotNull(db.SafeZoneRegistrations.Single().AcknowledgedAtUtc);
    }

    [Fact]
    public async Task Candidate_RefusesStaleGenerationWithoutPersisting()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new SubmitGeofenceCandidateCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new SubmitGeofenceCandidateCommand(
            fixture.MemberUserId, Guid.NewGuid(), fixture.ZoneId, 2, GeofenceTransition.Enter,
            DateTime.UtcNow, 30.0444, 31.2357, 5)));

        Assert.Empty(db.GeofenceCandidates);
    }

    [Fact]
    public void TracerHandlers_DoNotReferenceSosOrPushServices()
    {
        var tracerPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "src", "SafePath.Application", "Geofencing", "GeofenceTracer.cs");
        var source = File.ReadAllText(Path.GetFullPath(tracerPath));

        Assert.DoesNotContain("Sos", source, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("AlertHub", source, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Push", source, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<(Guid ZoneId, Guid GuardianUserId, Guid MemberUserId)> SeedAsync(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        var zoneId = Guid.NewGuid();
        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = memberId, Email = $"member-{memberId}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Tracer", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        db.SafeZones.Add(new SafeZone { Id = zoneId, FamilyId = familyId, AssignedMemberUserId = memberId, CreatedByUserId = guardianId, Category = SafeZoneCategory.Home, Latitude = 30.0444, Longitude = 31.2357, RadiusMeters = 100, Sensitivity = SafeZoneSensitivity.Balanced, CreatedAtUtc = DateTime.UtcNow });
        db.SafeZoneRegistrations.Add(new SafeZoneRegistration { Id = Guid.NewGuid(), SafeZoneId = zoneId, MemberUserId = memberId, Generation = 1, IssuedAtUtc = DateTime.UtcNow });
        await db.SaveChangesAsync();
        return (zoneId, guardianId, memberId);
    }

    public void Dispose() => _factory.Dispose();
}
