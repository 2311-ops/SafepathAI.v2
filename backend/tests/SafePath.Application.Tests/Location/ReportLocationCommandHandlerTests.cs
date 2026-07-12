using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class ReportLocationCommandHandlerTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_ValidReport_PersistsOnePingAndBroadcastsToFamily()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, recipientId) = await SeedFamily(db);
        var broadcast = new RecordingLocationBroadcastService();
        var handler = new ReportLocationCommandHandler(db, new FamilyAuthorizationService(db), broadcast);
        var recordedAt = DateTime.UtcNow.AddSeconds(-30);

        await handler.Handle(new ReportLocationCommand(
            callerId,
            familyId,
            30.0444,
            31.2357,
            12.5,
            72,
            recordedAt));

        var ping = Assert.Single(db.LocationPings);
        Assert.Equal(callerId, ping.UserId);
        Assert.Equal(familyId, broadcast.FamilyId);
        Assert.Equal(callerId, broadcast.Update!.UserId);
        Assert.Equal(30.0444, broadcast.Update.Lat);
        Assert.Equal(31.2357, broadcast.Update.Lng);
        Assert.Equal(12.5, broadcast.Update.AccuracyMeters);
        Assert.Equal(72, broadcast.Update.BatteryPercent);
        Assert.Equal(recordedAt, broadcast.Update.RecordedAtUtc);
        Assert.Contains(callerId, broadcast.EligibleRecipientUserIds);
        Assert.Contains(recipientId, broadcast.EligibleRecipientUserIds);
        Assert.Equal(1, broadcast.BroadcastCount);
    }

    [Theory]
    [InlineData(91, 31.2357)]
    [InlineData(30.0444, 181)]
    public async Task Handle_OutOfRangeCoordinates_RejectsAndPersistsNothing(double latitude, double longitude)
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new ReportLocationCommandHandler(
            db,
            new FamilyAuthorizationService(db),
            new RecordingLocationBroadcastService());

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new ReportLocationCommand(
            callerId,
            familyId,
            latitude,
            longitude,
            10,
            null,
            DateTime.UtcNow.AddMinutes(-1))));

        Assert.Empty(db.LocationPings);
    }

    [Fact]
    public async Task Handle_FutureRecordedAt_RejectsAndPersistsNothing()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new ReportLocationCommandHandler(
            db,
            new FamilyAuthorizationService(db),
            new RecordingLocationBroadcastService());

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new ReportLocationCommand(
            callerId,
            familyId,
            30.0444,
            31.2357,
            10,
            null,
            DateTime.UtcNow.AddMinutes(1))));

        Assert.Empty(db.LocationPings);
    }

    [Fact]
    public async Task Handle_UsesCommandCallerUserIdForPersistedPing()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new ReportLocationCommandHandler(
            db,
            new FamilyAuthorizationService(db),
            new RecordingLocationBroadcastService());

        await handler.Handle(new ReportLocationCommand(
            callerId,
            familyId,
            30.0444,
            31.2357,
            10,
            null,
            DateTime.UtcNow.AddMinutes(-1)));

        Assert.Equal(callerId, Assert.Single(db.LocationPings).UserId);
    }

    private static async Task<(Guid FamilyId, Guid CallerId, Guid RecipientId)> SeedFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = "caller@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = recipientId, Email = "recipient@example.com", FullName = "Recipient", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = recipientId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = callerId,
                Role = Role.Member,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-2),
                IsActive = true,
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = recipientId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-1),
                IsActive = true,
            });

        await db.SaveChangesAsync();
        return (familyId, callerId, recipientId);
    }

    public void Dispose() => _factory.Dispose();
}

internal sealed class RecordingLocationBroadcastService : ILocationBroadcastService
{
    public int BroadcastCount { get; private set; }
    public Guid FamilyId { get; private set; }
    public LocationUpdateDto? Update { get; private set; }
    public IReadOnlyList<Guid> EligibleRecipientUserIds { get; private set; } = [];

    public Task BroadcastLocation(
        Guid familyId,
        LocationUpdateDto update,
        IEnumerable<Guid> eligibleRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        BroadcastCount++;
        FamilyId = familyId;
        Update = update;
        EligibleRecipientUserIds = eligibleRecipientUserIds.ToList();
        return Task.CompletedTask;
    }

    public Task BroadcastPresence(Guid familyId, PresenceChangeDto change, CancellationToken cancellationToken = default) =>
        Task.CompletedTask;
}
