using Microsoft.EntityFrameworkCore;
using Moq;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Sos;

/// <summary>
/// Covers self-cancel (parallel follow-up, never a retraction — D-05/D-24) and acknowledge
/// (per-recipient, never inferred from a send — D-22).
/// </summary>
public class CancelSosCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Cancel_SetsCanceledStatusAndAudit()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedTriggeredSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new CancelSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        var result = await handler.Handle(new CancelSosCommand(sessionId, triggeredByUserId));

        Assert.Equal(SosSessionStatus.Canceled, result.Session.Status);
        Assert.NotNull(result.Session.CanceledAtUtc);
        var session = await db.SosSessions.SingleAsync(s => s.Id == sessionId);
        Assert.Equal(triggeredByUserId, session.CanceledByUserId);
    }

    [Fact]
    public async Task Cancel_LeavesOriginalDeliveryRowsIntact()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedTriggeredSession(db, recipientCount: 2);
        var beforeCount = db.SosDeliveryAttempts.Count(a => a.SosSessionId == sessionId);
        var beforeStatuses = db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId).Select(a => a.Status).ToList();
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new CancelSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        await handler.Handle(new CancelSosCommand(sessionId, triggeredByUserId));

        var afterAttempts = db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId).ToList();
        Assert.Equal(beforeCount, afterAttempts.Count);
        Assert.Equal(beforeStatuses, afterAttempts.Select(a => a.Status).ToList());
    }

    [Fact]
    public async Task Cancel_BroadcastsSosCanceledToTheSameRecipients()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, triggeredByUserId, recipientIds) = await SeedTriggeredSession(db, recipientCount: 2);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosCanceled(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosCanceledDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new CancelSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        await handler.Handle(new CancelSosCommand(sessionId, triggeredByUserId));

        broadcast.Verify(
            b => b.SosCanceled(
                familyId,
                It.Is<IEnumerable<Guid>>(ids => new HashSet<Guid>(ids).SetEquals(recipientIds)),
                It.Is<SosCanceledDto>(dto => dto.SosSessionId == sessionId && dto.CanceledByUserId == triggeredByUserId),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Cancel_IsIdempotent()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedTriggeredSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosCanceled(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosCanceledDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new CancelSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        var first = await handler.Handle(new CancelSosCommand(sessionId, triggeredByUserId));
        var second = await handler.Handle(new CancelSosCommand(sessionId, triggeredByUserId));

        Assert.Equal(first.Session.CanceledAtUtc, second.Session.CanceledAtUtc);
        broadcast.Verify(
            b => b.SosCanceled(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosCanceledDto>(), It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Cancel_RejectsANonTriggeringUser()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, recipientIds) = await SeedTriggeredSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new CancelSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new CancelSosCommand(sessionId, recipientIds[0])));

        var session = await db.SosSessions.SingleAsync(s => s.Id == sessionId);
        Assert.Equal(SosSessionStatus.Active, session.Status);
    }

    [Fact]
    public async Task Acknowledge_SetsAcknowledgedOnlyForTheCallersOwnRow()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, recipientIds) = await SeedTriggeredSession(db, recipientCount: 2);
        var acknowledgingRecipient = recipientIds[0];
        var otherRecipient = recipientIds[1];
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.DeliveryStatusChanged(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosDeliveryStatusChangedDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new AcknowledgeSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        await handler.Handle(new AcknowledgeSosCommand(sessionId, acknowledgingRecipient));

        var acknowledged = await db.SosDeliveryAttempts.SingleAsync(
            a => a.SosSessionId == sessionId && a.RecipientUserId == acknowledgingRecipient);
        Assert.Equal(SosDeliveryStatus.Acknowledged, acknowledged.Status);
        Assert.NotNull(acknowledged.AcknowledgedAtUtc);

        var untouched = await db.SosDeliveryAttempts.SingleAsync(
            a => a.SosSessionId == sessionId && a.RecipientUserId == otherRecipient);
        Assert.Equal(SosDeliveryStatus.NotAttempted, untouched.Status);
        Assert.Null(untouched.AcknowledgedAtUtc);
    }

    [Fact]
    public async Task Acknowledge_RejectsAUserOutsideTheFamily()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _) = await SeedTriggeredSession(db, recipientCount: 1);
        var outsiderId = Guid.NewGuid();
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new AcknowledgeSosCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new AcknowledgeSosCommand(sessionId, outsiderId)));
    }

    private async Task<(Guid FamilyId, Guid SosSessionId, Guid TriggeredByUserId, List<Guid> RecipientIds)> SeedTriggeredSession(
        ApplicationDbContext db,
        int recipientCount)
    {
        var familyId = Guid.NewGuid();
        var triggeredByUserId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var recipientIds = new List<Guid>();

        db.Users.Add(new User
        {
            Id = triggeredByUserId,
            Email = $"caller-{triggeredByUserId}@example.com",
            FullName = "Caller",
            Role = Role.Member,
            CreatedAt = DateTime.UtcNow,
        });
        db.Families.Add(new Family { Id = familyId, Name = "Cancel Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = triggeredByUserId,
            Role = Role.Member,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });

        db.SosSessions.Add(new SosSession
        {
            Id = sessionId,
            FamilyId = familyId,
            TriggeredByUserId = triggeredByUserId,
            Kind = SosKind.Visible,
            Status = SosSessionStatus.Active,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });

        for (var i = 0; i < recipientCount; i++)
        {
            var recipientId = Guid.NewGuid();
            recipientIds.Add(recipientId);
            db.Users.Add(new User
            {
                Id = recipientId,
                Email = $"guardian-{recipientId}@example.com",
                FullName = $"Guardian {i}",
                Role = Role.Guardian,
                CreatedAt = DateTime.UtcNow,
            });
            db.FamilyMembers.Add(new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = recipientId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow,
                IsActive = true,
            });
            db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
            {
                Id = Guid.NewGuid(),
                SosSessionId = sessionId,
                RecipientUserId = recipientId,
                Channel = AlertChannel.SignalR,
                Status = SosDeliveryStatus.NotAttempted,
            });
        }

        await db.SaveChangesAsync();
        return (familyId, sessionId, triggeredByUserId, recipientIds);
    }

    public void Dispose() => _factory.Dispose();
}
