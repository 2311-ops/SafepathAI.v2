using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Sos;

public class TriggerSosCommandHandlerTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_PersistsSessionWithClientSuppliedId()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));
        var sosSessionId = Guid.NewGuid();

        await handler.Handle(new TriggerSosCommand(
            sosSessionId, callerId, familyId, 30.0444, 31.2357, 10, DateTime.UtcNow));

        var session = Assert.Single(db.SosSessions);
        Assert.Equal(sosSessionId, session.Id);
    }

    [Fact]
    public async Task Handle_IsIdempotentForRepeatedSessionId()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));
        var sosSessionId = Guid.NewGuid();
        var command = new TriggerSosCommand(sosSessionId, callerId, familyId, 30.0444, 31.2357, 10, DateTime.UtcNow);

        var first = await handler.Handle(command);
        var attemptCountAfterFirst = db.SosDeliveryAttempts.Count();
        var second = await handler.Handle(command);

        Assert.Single(db.SosSessions);
        Assert.Equal(attemptCountAfterFirst, db.SosDeliveryAttempts.Count());
        Assert.False(first.WasExistingSession);
        Assert.True(second.WasExistingSession);
        Assert.Equal(first.Session.SosSessionId, second.Session.SosSessionId);
    }

    [Fact]
    public async Task Handle_CreatesOneAttemptPerGuardianRecipient()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db, extraGuardians: 2);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var attempts = db.SosDeliveryAttempts.ToList();
        Assert.Equal(2, attempts.Count);
        Assert.All(attempts, a => Assert.Equal(AlertChannel.SignalR, a.Channel));
        Assert.All(attempts, a => Assert.Equal(SosDeliveryStatus.NotAttempted, a.Status));
    }

    [Fact]
    public async Task Handle_ExcludesTriggeringUserFromRecipients()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db, callerRole: Role.Guardian, extraGuardians: 1);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var attempts = db.SosDeliveryAttempts.ToList();
        Assert.DoesNotContain(attempts, a => a.RecipientUserId == callerId);
    }

    [Fact]
    public async Task Handle_ThrowsWhenCallerIsNotAFamilyMember()
    {
        await using var db = _factory.CreateContext();
        var (familyId, _, _) = await SeedFamily(db);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));
        var outsiderId = Guid.NewGuid();

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), outsiderId, familyId, null, null, null, DateTime.UtcNow)));

        Assert.Empty(db.SosSessions);
    }

    [Fact]
    public async Task Handle_DoesNotWriteLocationPings()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, 30.0444, 31.2357, 10, DateTime.UtcNow));

        Assert.Empty(db.LocationPings);
    }

    [Fact]
    public async Task Handle_RejectsOutOfRangeCoordinates()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, 91, 31.2357, 10, DateTime.UtcNow)));
    }

    private static async Task<(Guid FamilyId, Guid CallerId, Guid RecipientId)> SeedFamily(
        ApplicationDbContext db,
        Role callerRole = Role.Member,
        int extraGuardians = 1)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        db.Users.Add(new User { Id = callerId, Email = "caller@example.com", FullName = "Caller", Role = callerRole, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = callerId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = callerId,
            Role = callerRole,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow.AddMinutes(-2),
            IsActive = true,
        });

        for (var i = 0; i < extraGuardians; i++)
        {
            var guardianId = i == 0 ? recipientId : Guid.NewGuid();
            db.Users.Add(new User { Id = guardianId, Email = $"guardian{i}@example.com", FullName = $"Guardian {i}", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
            db.FamilyMembers.Add(new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = guardianId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-1),
                IsActive = true,
            });
        }

        await db.SaveChangesAsync();
        return (familyId, callerId, recipientId);
    }

    public void Dispose() => _factory.Dispose();
}
