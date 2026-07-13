using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Privacy;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

namespace SafePath.Application.Tests.Privacy;

public class BroadcastGatingTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task UpdateSharingPreference_UpsertsOnlyTheCallerOwnedPreference()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        var handler = new UpdateSharingPreferenceCommandHandler(db, new FamilyAuthorizationService(db));
        var expiresAt = DateTime.UtcNow.AddHours(4);

        var result = await handler.Handle(new UpdateSharingPreferenceCommand(
            seed.OwnerUserId,
            seed.FamilyId,
            seed.RecipientMemberId,
            SharedDataType.LiveLocation,
            IsEnabled: false,
            expiresAt));

        Assert.Equal(seed.OwnerUserId, db.SharingPreferences.Single().OwnerUserId);
        Assert.Equal(seed.RecipientMemberId, result.RecipientMemberId);
        Assert.False(result.IsEnabled);

        await handler.Handle(new UpdateSharingPreferenceCommand(
            seed.OwnerUserId,
            seed.FamilyId,
            seed.RecipientMemberId,
            SharedDataType.LiveLocation,
            IsEnabled: true,
            ExpiresAtUtc: null));

        var stored = Assert.Single(db.SharingPreferences);
        Assert.Equal(seed.OwnerUserId, stored.OwnerUserId);
        Assert.True(stored.IsEnabled);
        Assert.Null(stored.ExpiresAtUtc);
    }

    [Fact]
    public async Task GetSharingMatrix_ReturnsOnlyTheCallerOwnedMatrix()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.SharingPreferences.AddRange(
            NewPreference(seed.FamilyId, seed.OwnerUserId, seed.RecipientMemberId, SharedDataType.LiveLocation, false),
            NewPreference(seed.FamilyId, seed.RecipientUserId, seed.OwnerMemberId, SharedDataType.LiveLocation, true));
        await db.SaveChangesAsync();
        var handler = new GetSharingMatrixQueryHandler(db, new FamilyAuthorizationService(db));

        var matrix = await handler.Handle(new GetSharingMatrixQuery(seed.OwnerUserId, seed.FamilyId));

        var entry = Assert.Single(matrix.Entries);
        Assert.Equal(seed.RecipientMemberId, entry.RecipientMemberId);
        Assert.Equal("Recipient", entry.RecipientName);
        Assert.Equal(SharedDataType.LiveLocation, entry.DataType);
        Assert.False(entry.IsEnabled);
    }

    [Fact]
    public async Task ReportLocation_DisabledLiveLocationRecipientReceivesNoBroadcast()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.SharingPreferences.Add(NewPreference(
            seed.FamilyId,
            seed.OwnerUserId,
            seed.RecipientMemberId,
            SharedDataType.LiveLocation,
            false));
        await db.SaveChangesAsync();
        var broadcast = new RecordingLocationBroadcastService();
        var sharing = new SharingAuthorizationService(db);
        var handler = new ReportLocationCommandHandler(
            db,
            new FamilyAuthorizationService(db),
            broadcast,
            sharing,
            new LowBatteryAlertTracker());

        await handler.Handle(new ReportLocationCommand(
            seed.OwnerUserId,
            seed.FamilyId,
            30.0444,
            31.2357,
            8,
            90,
            DateTime.UtcNow.AddSeconds(-10)));

        Assert.Contains(seed.OwnerUserId, broadcast.EligibleRecipientUserIds);
        Assert.DoesNotContain(seed.RecipientUserId, broadcast.EligibleRecipientUserIds);
    }

    [Fact]
    public async Task GetLiveLocations_DisabledLiveLocationKeepsMemberButNullsCoordinates()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.LocationPings.Add(new LocationPing
        {
            Id = Guid.NewGuid(),
            UserId = seed.OwnerUserId,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 10,
            BatteryPercent = 80,
            RecordedAtUtc = DateTime.UtcNow.AddSeconds(-20),
            ReceivedAtUtc = DateTime.UtcNow,
        });
        db.SharingPreferences.Add(NewPreference(
            seed.FamilyId,
            seed.OwnerUserId,
            seed.RecipientMemberId,
            SharedDataType.LiveLocation,
            false));
        await db.SaveChangesAsync();
        var sharing = new SharingAuthorizationService(db);
        var handler = new GetLiveLocationsQueryHandler(
            db,
            new FamilyAuthorizationService(db),
            new FakePresenceQuery(),
            sharing);

        var result = await handler.Handle(new GetLiveLocationsQuery(seed.RecipientUserId, seed.FamilyId));

        var owner = result.Single(location => location.UserId == seed.OwnerUserId);
        Assert.Equal("Owner", owner.DisplayName);
        Assert.Null(owner.Lat);
        Assert.Null(owner.Lng);
        Assert.Null(owner.AccuracyMeters);
        Assert.Null(owner.BatteryPercent);
        Assert.Null(owner.RecordedAtUtc);
    }

    private static async Task<SharingSeed> SeedFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var ownerUserId = Guid.NewGuid();
        var recipientUserId = Guid.NewGuid();
        var ownerMemberId = Guid.NewGuid();
        var recipientMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = ownerUserId, Email = "owner@example.com", FullName = "Owner", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = recipientUserId, Email = "recipient@example.com", FullName = "Recipient", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Privacy Family", CreatedByUserId = recipientUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = ownerMemberId,
                FamilyId = familyId,
                UserId = ownerUserId,
                Role = Role.Member,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-2),
                IsActive = true,
            },
            new FamilyMember
            {
                Id = recipientMemberId,
                FamilyId = familyId,
                UserId = recipientUserId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-1),
                IsActive = true,
            });
        await db.SaveChangesAsync();

        return new SharingSeed(familyId, ownerUserId, recipientUserId, ownerMemberId, recipientMemberId);
    }

    private static SharingPreference NewPreference(
        Guid familyId,
        Guid ownerUserId,
        Guid? recipientMemberId,
        SharedDataType dataType,
        bool isEnabled) =>
        new()
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            OwnerUserId = ownerUserId,
            RecipientMemberId = recipientMemberId,
            DataType = dataType,
            IsEnabled = isEnabled,
        };

    public void Dispose() => _factory.Dispose();

    private sealed record SharingSeed(
        Guid FamilyId,
        Guid OwnerUserId,
        Guid RecipientUserId,
        Guid OwnerMemberId,
        Guid RecipientMemberId);
}

internal sealed class RecordingLocationBroadcastService : ILocationBroadcastService
{
    public IReadOnlyList<Guid> EligibleRecipientUserIds { get; private set; } = [];

    public Task BroadcastLocation(
        Guid familyId,
        LocationUpdateDto update,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        EligibleRecipientUserIds = eligibleRecipientUserIds.ToList();
        return Task.CompletedTask;
    }

    public Task BroadcastPresence(Guid familyId, PresenceChangeDto change, CancellationToken cancellationToken = default) =>
        Task.CompletedTask;

    public Task BroadcastLowBattery(
        Guid familyId,
        LowBatteryAlertDto alert,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default) =>
        Task.CompletedTask;

    public Task BroadcastProfileUpdated(
        Guid familyId,
        ProfileUpdateDto update,
        CancellationToken cancellationToken = default) =>
        Task.CompletedTask;
}

internal sealed class FakePresenceQuery : IPresenceQuery
{
    public bool IsOnline(Guid userId) => false;
}
