using SafePath.Application.Geofencing;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Geofencing;

public sealed class ZoneCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Create_UsesSafeDefaultsAndReturnsOnlyServerRegistrationState()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new CreateZoneCommandHandler(db, new FamilyAuthorizationService(db));

        var result = await handler.Handle(new CreateZoneCommand(
            fixture.GuardianUserId, fixture.FamilyId, SafeZoneCategory.Home, null,
            30.0444, 31.2357, 100, fixture.MemberUserId, SafeZoneSensitivity.Balanced,
            [], false));

        Assert.True(result.Active);
        Assert.True(result.NeedsLocationPermission);
        Assert.True(result.NeedsSync);
        Assert.Single(db.SafeZoneRecipients);
        Assert.Equal(fixture.GuardianUserId, db.SafeZoneRecipients.Single().RecipientUserId);
        Assert.False(db.SafeZones.Single().NotifyAssignedMember);
    }

    [Theory]
    [InlineData(99)]
    [InlineData(2001)]
    public async Task Create_RejectsRadiusOutsideSupportedNativeRange(double radiusMeters)
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var handler = new CreateZoneCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new CreateZoneCommand(
            fixture.GuardianUserId, fixture.FamilyId, SafeZoneCategory.Home, null,
            30.0444, 31.2357, radiusMeters, fixture.MemberUserId, SafeZoneSensitivity.Balanced,
            [fixture.GuardianUserId], false)));
    }

    [Fact]
    public async Task UpdateDisableAndDelete_AdvanceGenerationAndRetainActivity()
    {
        await using var db = _factory.CreateContext();
        var fixture = await SeedAsync(db);
        var create = new CreateZoneCommandHandler(db, new FamilyAuthorizationService(db));
        var created = await create.Handle(new CreateZoneCommand(
            fixture.GuardianUserId, fixture.FamilyId, SafeZoneCategory.Home, null,
            30.0444, 31.2357, 100, fixture.MemberUserId, SafeZoneSensitivity.Balanced,
            [fixture.GuardianUserId], false));
        db.GeofenceActivities.Add(new GeofenceActivity { Id = Guid.NewGuid(), SafeZoneId = created.ZoneId, SafeZoneDisplayName = "Home", MemberUserId = fixture.MemberUserId, Transition = GeofenceTransition.Enter, OccurredAtUtc = DateTime.UtcNow, RecordedAtUtc = DateTime.UtcNow, RetainUntilUtc = DateTime.UtcNow.AddDays(7) });
        await db.SaveChangesAsync();

        var update = new UpdateZoneCommandHandler(db, new FamilyAuthorizationService(db));
        var updated = await update.Handle(new UpdateZoneCommand(
            fixture.GuardianUserId, fixture.FamilyId, created.ZoneId, SafeZoneCategory.Home, null,
            30.0445, 31.2358, 150, fixture.MemberUserId, SafeZoneSensitivity.Conservative,
            [fixture.GuardianUserId], true));
        var disable = new DisableZoneCommandHandler(db, new FamilyAuthorizationService(db));
        var disabled = await disable.Handle(new DisableZoneCommand(fixture.GuardianUserId, fixture.FamilyId, created.ZoneId));
        var delete = new DeleteZoneCommandHandler(db, new FamilyAuthorizationService(db));
        var deleted = await delete.Handle(new DeleteZoneCommand(fixture.GuardianUserId, fixture.FamilyId, created.ZoneId));

        Assert.Equal(2, updated.RegistrationGeneration);
        Assert.Equal(3, disabled.RegistrationGeneration);
        Assert.False(deleted.Active);
        Assert.Single(db.GeofenceActivities);
    }

    private static async Task<(Guid FamilyId, Guid GuardianUserId, Guid MemberUserId)> SeedAsync(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = memberId, Email = $"member-{memberId}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Zones", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        await db.SaveChangesAsync();
        return (familyId, guardianId, memberId);
    }

    public void Dispose() => _factory.Dispose();
}
