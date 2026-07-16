using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class GetLocationHistoryQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_AuthorizedCaller_ReturnsOrderedPolylinePointsAndStopsWithinRange()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedHistoryFamily(db);
        var from = DateTime.UtcNow.AddHours(-1);
        var to = from.AddMinutes(30);
        db.LocationPings.AddRange(
            NewPing(seed.TargetUserId, 29.9000, 31.0000, from.AddMinutes(-5)),
            NewPing(seed.TargetUserId, 30.0444, 31.2357, from.AddMinutes(10)),
            NewPing(seed.TargetUserId, 30.0445, 31.2358, from.AddMinutes(12)),
            NewPing(seed.TargetUserId, 30.0446, 31.2359, from.AddMinutes(16)),
            NewPing(seed.TargetUserId, 30.0700, 31.2600, to.AddMinutes(5)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        var result = await handler.Handle(new GetLocationHistoryQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            from,
            to));

        Assert.Equal(3, result.PolylinePoints.Count);
        Assert.Equal(
            [from.AddMinutes(10), from.AddMinutes(12), from.AddMinutes(16)],
            result.PolylinePoints.Select(p => p.RecordedAtUtc).ToArray());
        Assert.All(result.PolylinePoints, p => Assert.InRange(p.RecordedAtUtc, from, to));
        var stop = Assert.Single(result.Stops);
        Assert.Equal(from.AddMinutes(10), stop.StartUtc);
        Assert.Equal(from.AddMinutes(16), stop.EndUtc);
    }

    [Fact]
    public async Task Handle_WhenHistorySharingDenied_ThrowsBeforeReturningPoints()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedHistoryFamily(db);
        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = seed.FamilyId,
            OwnerUserId = seed.TargetUserId,
            RecipientMemberId = seed.CallerMemberId,
            DataType = SharedDataType.History,
            IsEnabled = false,
        });
        db.LocationPings.Add(NewPing(seed.TargetUserId, 30.0444, 31.2357, DateTime.UtcNow.AddMinutes(-5)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetLocationHistoryQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow)));
    }

    [Fact]
    public async Task Handle_ByNonMember_IsDeniedBeforeReadingPings()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedHistoryFamily(db);
        db.LocationPings.Add(NewPing(seed.TargetUserId, 30.0444, 31.2357, DateTime.UtcNow.AddMinutes(-5)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetLocationHistoryQuery(
            Guid.NewGuid(),
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow)));
    }

    [Fact]
    public async Task Handle_TargetOutsideFamily_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedHistoryFamily(db);
        var outsideUserId = Guid.NewGuid();
        db.Users.Add(new User
        {
            Id = outsideUserId,
            Email = "outside@example.com",
            FullName = "Outside",
            Role = Role.Member,
            CreatedAt = DateTime.UtcNow,
        });
        db.LocationPings.Add(NewPing(outsideUserId, 30.0444, 31.2357, DateTime.UtcNow.AddMinutes(-5)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new GetLocationHistoryQuery(
            seed.CallerUserId,
            seed.FamilyId,
            outsideUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow)));
    }

    [Fact]
    public async Task Handle_EmptyRange_ReturnsEmptyHistory()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedHistoryFamily(db);
        db.LocationPings.Add(NewPing(seed.TargetUserId, 30.0444, 31.2357, DateTime.UtcNow.AddHours(-2)));
        await db.SaveChangesAsync();
        var handler = NewHandler(db);

        var result = await handler.Handle(new GetLocationHistoryQuery(
            seed.CallerUserId,
            seed.FamilyId,
            seed.TargetUserId,
            DateTime.UtcNow.AddHours(-1),
            DateTime.UtcNow));

        Assert.Empty(result.PolylinePoints);
        Assert.Empty(result.Stops);
    }

    private static GetLocationHistoryQueryHandler NewHandler(ApplicationDbContext db) =>
        new(db, new FamilyAuthorizationService(db), new SharingAuthorizationService(db));

    private static async Task<HistorySeed> SeedHistoryFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerUserId = Guid.NewGuid();
        var targetUserId = Guid.NewGuid();
        var callerMemberId = Guid.NewGuid();
        var targetMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerUserId, Email = "caller@example.com", FullName = "Caller", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = targetUserId, Email = "target@example.com", FullName = "Target", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "History Family", CreatedByUserId = callerUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            NewMember(callerMemberId, familyId, callerUserId, Role.Guardian, DateTime.UtcNow.AddMinutes(-2)),
            NewMember(targetMemberId, familyId, targetUserId, Role.Member, DateTime.UtcNow.AddMinutes(-1)));
        await db.SaveChangesAsync();

        return new HistorySeed(familyId, callerUserId, targetUserId, callerMemberId, targetMemberId);
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

    private sealed record HistorySeed(
        Guid FamilyId,
        Guid CallerUserId,
        Guid TargetUserId,
        Guid CallerMemberId,
        Guid TargetMemberId);
}
