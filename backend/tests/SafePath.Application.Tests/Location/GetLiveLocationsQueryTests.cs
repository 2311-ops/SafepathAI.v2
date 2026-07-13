using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Constants;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class GetLiveLocationsQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public void HaversineMeters_ForNearbyMeridianPoints_IsWithinOnePercent()
    {
        var distance = GeoMath.HaversineMeters(30.0444, 31.2357, 30.0454, 31.2357);

        Assert.InRange(distance, 110, 113);
    }

    [Fact]
    public async Task LocationPing_RoundTripsThroughSqliteContext_ByUserAndRecordedAt()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var recordedAt = DateTime.UtcNow.AddMinutes(-2);

        db.Users.Add(new User
        {
            Id = userId,
            Email = "member@example.com",
            FullName = "Member One",
            Role = null,
            CreatedAt = DateTime.UtcNow,
        });
        db.LocationPings.Add(new LocationPing
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 14.2,
            BatteryPercent = 86,
            RecordedAtUtc = recordedAt,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var loaded = await db.LocationPings.SingleAsync(p =>
            p.UserId == userId &&
            p.RecordedAtUtc >= recordedAt.AddSeconds(-1) &&
            p.RecordedAtUtc <= recordedAt.AddSeconds(1));

        Assert.Equal(userId, loaded.UserId);
        Assert.Equal(30.0444, loaded.Latitude);
        Assert.Equal(31.2357, loaded.Longitude);
        Assert.Equal(14.2, loaded.AccuracyMeters);
        Assert.Equal(86, loaded.BatteryPercent);
    }

    [Fact]
    public void DwellTimeDefaults_ExposePhaseTwoStopThresholds()
    {
        Assert.Equal(100, DwellTimeDefaults.RadiusMeters);
        Assert.Equal(TimeSpan.FromMinutes(5), DwellTimeDefaults.MinDwell);
    }

    [Fact]
    public async Task Handle_ByFamilyMember_ReturnsActiveMembersWithLatestPingAndOnlineFlag()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, memberId, memberWithoutPingId) = await SeedLiveLocationFamily(db);
        var older = DateTime.UtcNow.AddMinutes(-10);
        var latest = DateTime.UtcNow.AddMinutes(-1);
        db.LocationPings.AddRange(
            NewPing(memberId, 30.0001, 31.0001, older),
            NewPing(memberId, 30.0444, 31.2357, latest));
        await db.SaveChangesAsync();
        var presence = new FakePresenceQuery();
        var handler = new GetLiveLocationsQueryHandler(
            db,
            new FamilyAuthorizationService(db),
            presence,
            new SharingAuthorizationService(db));

        var result = await handler.Handle(new GetLiveLocationsQuery(callerId, familyId));

        Assert.Equal(3, result.Count);
        var member = result.Single(location => location.UserId == memberId);
        Assert.Equal("Tracked Member", member.DisplayName);
        Assert.Equal(30.0444, member.Lat);
        Assert.Equal(31.2357, member.Lng);
        Assert.Equal(latest, member.RecordedAtUtc);
        Assert.True(member.IsOnline);

        var noPing = result.Single(location => location.UserId == memberWithoutPingId);
        Assert.Null(noPing.Lat);
        Assert.Null(noPing.Lng);
        Assert.False(noPing.IsOnline);
    }

    [Fact]
    public async Task Handle_SignsProfileImageUrlOnlyWhenViewerCanSeeLocation()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, memberId, _) = await SeedLiveLocationFamily(db);
        var callerMemberRow = await db.FamilyMembers.SingleAsync(m => m.FamilyId == familyId && m.UserId == callerId);
        var member = await db.Users.SingleAsync(u => u.Id == memberId);
        member.ProfileImagePath = $"avatars/{memberId}/avatar.jpg";
        db.LocationPings.Add(NewPing(memberId, 30.0444, 31.2357, DateTime.UtcNow.AddMinutes(-1)));
        await db.SaveChangesAsync();
        var storage = new FakeProfileImageStorage();
        var handler = new GetLiveLocationsQueryHandler(
            db,
            new FamilyAuthorizationService(db),
            new FakePresenceQuery(),
            new SharingAuthorizationService(db),
            new ProfileImageUrlFactory(storage));

        var allowed = await handler.Handle(new GetLiveLocationsQuery(callerId, familyId));

        Assert.Equal("signed://avatar", allowed.Single(location => location.UserId == memberId).ProfileImageUrl);

        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            OwnerUserId = memberId,
            RecipientMemberId = callerMemberRow.Id,
            DataType = SharedDataType.LiveLocation,
            IsEnabled = false,
        });
        await db.SaveChangesAsync();

        var denied = await handler.Handle(new GetLiveLocationsQuery(callerId, familyId));

        Assert.Null(denied.Single(location => location.UserId == memberId).Lat);
        Assert.Null(denied.Single(location => location.UserId == memberId).ProfileImageUrl);
    }

    [Fact]
    public async Task Handle_ByNonMember_IsDeniedBeforeReturningLocationRows()
    {
        await using var db = _factory.CreateContext();
        var (familyId, _, _, _) = await SeedLiveLocationFamily(db);
        var handler = new GetLiveLocationsQueryHandler(
            db,
            new FamilyAuthorizationService(db),
            new FakePresenceQuery(),
            new SharingAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new GetLiveLocationsQuery(Guid.NewGuid(), familyId)));
    }

    [Fact]
    public async Task Handle_CombinesConnectionStateAndPingRecencyForPresence()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, staleConnectedId, recentDisconnectedId) = await SeedLiveLocationFamily(db);
        var staleRecordedAt = DateTime.UtcNow.AddMinutes(-30);
        var recentRecordedAt = DateTime.UtcNow.AddSeconds(-30);
        db.LocationPings.AddRange(
            NewPing(staleConnectedId, 30.0444, 31.2357, staleRecordedAt),
            NewPing(recentDisconnectedId, 30.0555, 31.2468, recentRecordedAt));
        await db.SaveChangesAsync();
        var presence = new FakePresenceQuery(staleConnectedId);
        var handler = new GetLiveLocationsQueryHandler(
            db,
            new FamilyAuthorizationService(db),
            presence,
            new SharingAuthorizationService(db));

        var result = await handler.Handle(new GetLiveLocationsQuery(callerId, familyId));

        var staleConnected = result.Single(location => location.UserId == staleConnectedId);
        Assert.True(staleConnected.IsOnline);
        Assert.Equal(staleRecordedAt, staleConnected.RecordedAtUtc);

        var recentDisconnected = result.Single(location => location.UserId == recentDisconnectedId);
        Assert.True(recentDisconnected.IsOnline);
        Assert.Equal(recentRecordedAt, recentDisconnected.RecordedAtUtc);
    }

    private static async Task<(Guid FamilyId, Guid CallerId, Guid MemberId, Guid MemberWithoutPingId)> SeedLiveLocationFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        var memberWithoutPingId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = "caller@example.com", FullName = "Caller Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = memberId, Email = "tracked@example.com", FullName = "Tracked Member", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = memberWithoutPingId, Email = "quiet@example.com", FullName = "Quiet Member", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Live Family", CreatedByUserId = callerId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            NewMember(familyId, callerId, Role.Guardian, DateTime.UtcNow.AddMinutes(-3)),
            NewMember(familyId, memberId, Role.Member, DateTime.UtcNow.AddMinutes(-2)),
            NewMember(familyId, memberWithoutPingId, Role.Member, DateTime.UtcNow.AddMinutes(-1)));
        await db.SaveChangesAsync();

        return (familyId, callerId, memberId, memberWithoutPingId);
    }

    private static FamilyMember NewMember(Guid familyId, Guid userId, Role role, DateTime joinedAt) => new()
    {
        Id = Guid.NewGuid(),
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
}

internal sealed class FakePresenceQuery : IPresenceQuery
{
    private readonly HashSet<Guid> _onlineUserIds;

    public FakePresenceQuery(params Guid[] onlineUserIds)
    {
        _onlineUserIds = onlineUserIds.ToHashSet();
    }

    public bool IsOnline(Guid userId) => _onlineUserIds.Contains(userId);
}

internal sealed class FakeProfileImageStorage : IProfileImageStorage
{
    public Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default) => Task.CompletedTask;

    public Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default) => Task.CompletedTask;

    public Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default)
    {
        Assert.Equal(TimeSpan.FromHours(1), ttl);
        return Task.FromResult("signed://avatar");
    }

    public string GetAvatarObjectPath(Guid userId) => $"avatars/{userId}/avatar.jpg";
}
