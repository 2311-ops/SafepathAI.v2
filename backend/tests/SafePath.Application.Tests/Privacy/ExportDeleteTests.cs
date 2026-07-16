using SafePath.Application.Privacy;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Privacy;

public class ExportDeleteTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task ExportMyData_ReturnsOnlyCallerOwnedLocationAndSharingRows()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedData(db);
        var handler = new ExportMyDataQueryHandler(db);

        var export = await handler.Handle(new ExportMyDataQuery(seed.CallerUserId));

        var ping = Assert.Single(export.LocationPings);
        Assert.Equal(seed.CallerUserId, ping.UserId);
        Assert.Equal(30.0444, ping.Lat);
        Assert.Equal(31.2357, ping.Lng);
        Assert.Equal(55, ping.BatteryPercent);
        Assert.DoesNotContain(export.LocationPings, p => p.UserId == seed.OtherUserId);

        var preference = Assert.Single(export.SharingPreferences);
        Assert.Equal(seed.CallerUserId, preference.OwnerUserId);
        Assert.Equal(seed.FamilyId, preference.FamilyId);
        Assert.Equal(SharedDataType.LiveLocation, preference.DataType);
        Assert.DoesNotContain(export.SharingPreferences, p => p.OwnerUserId == seed.OtherUserId);
    }

    [Fact]
    public async Task DeleteMyData_HardDeletesOnlyCallerLocationRows()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedData(db);
        var handler = new DeleteMyDataCommandHandler(db);

        var result = await handler.Handle(new DeleteMyDataCommand(seed.CallerUserId));

        Assert.Equal(1, result.PingsDeleted);
        Assert.DoesNotContain(db.LocationPings, p => p.UserId == seed.CallerUserId);
        Assert.Contains(db.LocationPings, p => p.UserId == seed.OtherUserId);
    }

    [Fact]
    public async Task DeleteMyData_IsIdempotentWhenRunTwice()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedData(db);
        var handler = new DeleteMyDataCommandHandler(db);

        var first = await handler.Handle(new DeleteMyDataCommand(seed.CallerUserId));
        var second = await handler.Handle(new DeleteMyDataCommand(seed.CallerUserId));

        Assert.Equal(1, first.PingsDeleted);
        Assert.Equal(0, second.PingsDeleted);
        Assert.Contains(db.LocationPings, p => p.UserId == seed.OtherUserId);
    }

    private static async Task<ExportDeleteSeed> SeedData(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerUserId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var callerMemberId = Guid.NewGuid();
        var otherMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerUserId, Email = "caller@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = otherUserId, Email = "other@example.com", FullName = "Other", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Export Family", CreatedByUserId = otherUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = callerMemberId,
                FamilyId = familyId,
                UserId = callerUserId,
                Role = Role.Member,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-2),
                IsActive = true,
            },
            new FamilyMember
            {
                Id = otherMemberId,
                FamilyId = familyId,
                UserId = otherUserId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-1),
                IsActive = true,
            });
        db.LocationPings.AddRange(
            new LocationPing
            {
                Id = Guid.NewGuid(),
                UserId = callerUserId,
                Latitude = 30.0444,
                Longitude = 31.2357,
                AccuracyMeters = 8,
                BatteryPercent = 55,
                RecordedAtUtc = DateTime.UtcNow.AddMinutes(-10),
                ReceivedAtUtc = DateTime.UtcNow.AddMinutes(-9),
            },
            new LocationPing
            {
                Id = Guid.NewGuid(),
                UserId = otherUserId,
                Latitude = 29.9753,
                Longitude = 31.1376,
                AccuracyMeters = 12,
                BatteryPercent = 80,
                RecordedAtUtc = DateTime.UtcNow.AddMinutes(-8),
                ReceivedAtUtc = DateTime.UtcNow.AddMinutes(-7),
            });
        db.SharingPreferences.AddRange(
            new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                OwnerUserId = callerUserId,
                RecipientMemberId = otherMemberId,
                DataType = SharedDataType.LiveLocation,
                IsEnabled = true,
            },
            new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                OwnerUserId = otherUserId,
                RecipientMemberId = callerMemberId,
                DataType = SharedDataType.History,
                IsEnabled = false,
            });

        await db.SaveChangesAsync();
        return new ExportDeleteSeed(familyId, callerUserId, otherUserId);
    }

    public void Dispose() => _factory.Dispose();

    private sealed record ExportDeleteSeed(Guid FamilyId, Guid CallerUserId, Guid OtherUserId);
}
