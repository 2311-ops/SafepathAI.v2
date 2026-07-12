using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class GetTravelStatsQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_AuthorizedCaller_ReturnsDistanceTimeAwayAndStopCount()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedStatsFamily(db);
        var from = DateTime.UtcNow.AddHours(-1);
        var pings = new[]
        {
            NewPing(seed.TargetUserId, 30.0000, 31.0000, from),
            NewPing(seed.TargetUserId, 30.0001, 31.0000, from.AddMinutes(3)),
            NewPing(seed.TargetUserId, 30.0002, 31.0000, from.AddMinutes(6)),
            NewPing(seed.TargetUserId, 30.0012, 31.0000, from.AddMinutes(10)),
        };
        db.LocationPings.AddRange(pings);
        await db.SaveChangesAsync();
        var expectedDistance = GeoMath.HaversineMeters(30.0000, 31.0000, 30.0001, 31.0000) +
            GeoMath.HaversineMeters(30.0001, 31.0000, 30.0002, 31.0000) +
            GeoMath.HaversineMeters(30.0002, 31.0000, 30.0012, 31.0000);
        var handler = NewHandler(db);

        var result = await handler.Handle(new GetTravelStatsQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            from,
            from.AddMinutes(30)));

        Assert.InRange(result.TotalDistanceMeters, expectedDistance * 0.99, expectedDistance * 1.01);
        Assert.Equal(TimeSpan.FromMinutes(10), result.TimeAway);
        Assert.Equal(1, result.StopCount);
    }

    [Fact]
    public async Task Handle_WhenHistorySharingDenied_Throws()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedStatsFamily(db);
        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = seed.FamilyId,
            OwnerUserId = seed.TargetUserId,
            RecipientMemberId = seed.CallerMemberId,
            DataType = SharedDataType.History,
            IsEnabled = false,
        });
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetTravelStatsQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow)));
    }

    [Fact]
    public async Task Handle_ByNonMember_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedStatsFamily(db);
        var handler = NewHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetTravelStatsQuery(
            Guid.NewGuid(),
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow)));
    }

    [Fact]
    public async Task Handle_EmptyRange_ReturnsZeroedStats()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedStatsFamily(db);
        db.LocationPings.Add(NewPing(seed.TargetUserId, 30.0444, 31.2357, DateTime.UtcNow.AddHours(-2)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        var result = await handler.Handle(new GetTravelStatsQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow));

        Assert.Equal(0, result.TotalDistanceMeters);
        Assert.Equal(TimeSpan.Zero, result.TimeAway);
        Assert.Equal(0, result.StopCount);
    }

    private static GetTravelStatsQueryHandler NewHandler(ApplicationDbContext db) =>
        new(db, new FamilyAuthorizationService(db), new SharingAuthorizationService(db));

    private static async Task<StatsSeed> SeedStatsFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerUserId = Guid.NewGuid();
        var targetUserId = Guid.NewGuid();
        var callerMemberId = Guid.NewGuid();
        var targetMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerUserId, Email = "caller@example.com", FullName = "Caller", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = targetUserId, Email = "target@example.com", FullName = "Target", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Stats Family", CreatedByUserId = callerUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            NewMember(callerMemberId, familyId, callerUserId, Role.Guardian, DateTime.UtcNow.AddMinutes(-2)),
            NewMember(targetMemberId, familyId, targetUserId, Role.Member, DateTime.UtcNow.AddMinutes(-1)));
        await db.SaveChangesAsync();

        return new StatsSeed(familyId, callerUserId, targetUserId, callerMemberId, targetMemberId);
    }

    private static FamilyMember NewMember(Guid id, Guid familyId, Guid userId, Role role, DateTime joinedAt) => new()
    {
        Id = id,
        FamilyId = familyId,
        UserId = userId,
        Role = role,
        Permissions = PermissionLevel.FullLocation,
        JoinedAt = joinedAt,
        IsActive = true,
    };

    private static LocationPing NewPing(Guid userId, double latitude, double longitude, DateTime recordedAt) => new()
    {
        Id = Guid.NewGuid(),
        UserId = userId,
        Latitude = latitude,
        Longitude = longitude,
        AccuracyMeters = 10,
        BatteryPercent = null,
        RecordedAtUtc = recordedAt,
        ReceivedAtUtc = DateTime.UtcNow,
    };

    public void Dispose() => _factory.Dispose();

    private sealed record StatsSeed(
        Guid FamilyId,
        Guid CallerUserId,
        Guid TargetUserId,
        Guid CallerMemberId,
        Guid TargetMemberId);
}
