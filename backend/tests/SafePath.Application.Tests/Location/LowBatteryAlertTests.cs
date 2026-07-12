using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

namespace SafePath.Application.Tests.Location;

public class LowBatteryAlertTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public void ShouldAlert_FiresOncePerCrossingAndRearmsOnlyAboveClearBand()
    {
        var alreadyAlerted = false;

        Assert.False(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 50, out alreadyAlerted));
        Assert.False(alreadyAlerted);

        Assert.True(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 20, out alreadyAlerted));
        Assert.True(alreadyAlerted);

        Assert.False(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 15, out alreadyAlerted));
        Assert.True(alreadyAlerted);

        Assert.False(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 25, out alreadyAlerted));
        Assert.True(alreadyAlerted);

        Assert.False(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 26, out alreadyAlerted));
        Assert.False(alreadyAlerted);

        Assert.True(LowBatteryEvaluator.ShouldAlert(alreadyAlerted, 19, out alreadyAlerted));
        Assert.True(alreadyAlerted);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(21)]
    [InlineData(100)]
    public void ShouldAlert_NullOrAboveThresholdBatteryNeverAlerts(int? batteryPercent)
    {
        Assert.False(LowBatteryEvaluator.ShouldAlert(false, batteryPercent, out var alerted));
        Assert.False(alerted);
    }

    [Fact]
    public async Task Handle_LowBatteryCrossing_BroadcastsOnceToEligibleLiveLocationRecipients()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db, disableRecipientLiveLocation: true);
        var broadcast = new RecordingLowBatteryBroadcastService();
        var tracker = new LowBatteryAlertTracker();
        var handler = new ReportLocationCommandHandler(
            db,
            new FamilyAuthorizationService(db),
            broadcast,
            new SharingAuthorizationService(db),
            tracker);

        await handler.Handle(NewCommand(seed.OwnerUserId, seed.FamilyId, 30));
        await handler.Handle(NewCommand(seed.OwnerUserId, seed.FamilyId, 18));
        await handler.Handle(NewCommand(seed.OwnerUserId, seed.FamilyId, 16));
        await handler.Handle(NewCommand(seed.OwnerUserId, seed.FamilyId, 26));
        await handler.Handle(NewCommand(seed.OwnerUserId, seed.FamilyId, 19));

        Assert.Equal(2, broadcast.LowBatteryBroadcastCount);
        Assert.All(broadcast.LowBatteryAlerts, alert =>
        {
            Assert.Equal(seed.FamilyId, alert.FamilyId);
            Assert.Equal(seed.OwnerUserId, alert.Alert.UserId);
            Assert.Equal("Owner", alert.Alert.DisplayName);
            Assert.Contains(seed.OwnerUserId, alert.EligibleRecipientUserIds);
            Assert.DoesNotContain(seed.RecipientUserId, alert.EligibleRecipientUserIds);
        });
        Assert.Equal([18, 19], broadcast.LowBatteryAlerts.Select(alert => alert.Alert.BatteryPercent).ToArray());
    }

    private static ReportLocationCommand NewCommand(Guid ownerUserId, Guid familyId, int? batteryPercent) =>
        new(
            ownerUserId,
            familyId,
            30.0444,
            31.2357,
            8,
            batteryPercent,
            DateTime.UtcNow.AddSeconds(-10));

    private static async Task<LowBatterySeed> SeedFamily(
        ApplicationDbContext db,
        bool disableRecipientLiveLocation = false)
    {
        var familyId = Guid.NewGuid();
        var ownerUserId = Guid.NewGuid();
        var recipientUserId = Guid.NewGuid();
        var recipientMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = ownerUserId, Email = "owner@example.com", FullName = "Owner", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = recipientUserId, Email = "recipient@example.com", FullName = "Recipient", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Battery Family", CreatedByUserId = recipientUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
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

        if (disableRecipientLiveLocation)
        {
            db.SharingPreferences.Add(new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                OwnerUserId = ownerUserId,
                RecipientMemberId = recipientMemberId,
                DataType = SharedDataType.LiveLocation,
                IsEnabled = false,
            });
        }

        await db.SaveChangesAsync();
        return new LowBatterySeed(familyId, ownerUserId, recipientUserId);
    }

    public void Dispose() => _factory.Dispose();

    private sealed record LowBatterySeed(Guid FamilyId, Guid OwnerUserId, Guid RecipientUserId);
}

internal sealed class RecordingLowBatteryBroadcastService : ILocationBroadcastService
{
    public int LowBatteryBroadcastCount { get; private set; }
    public List<RecordedLowBatteryAlert> LowBatteryAlerts { get; } = [];

    public Task BroadcastLocation(
        Guid familyId,
        LocationUpdateDto update,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default) =>
        Task.CompletedTask;

    public Task BroadcastPresence(Guid familyId, PresenceChangeDto change, CancellationToken cancellationToken = default) =>
        Task.CompletedTask;

    public Task BroadcastLowBattery(
        Guid familyId,
        LowBatteryAlertDto alert,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        LowBatteryBroadcastCount++;
        LowBatteryAlerts.Add(new RecordedLowBatteryAlert(familyId, alert, eligibleRecipientUserIds.ToList()));
        return Task.CompletedTask;
    }
}

internal sealed record RecordedLowBatteryAlert(
    Guid FamilyId,
    LowBatteryAlertDto Alert,
    IReadOnlyList<Guid> EligibleRecipientUserIds);
