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
/// Covers 03-06's multi-device token registry, the FCM arm of SosAlertDispatcher (fan-out to
/// every registered device, honest Failed-not-Queued for a recipient with no device, Queued-not-
/// Delivered semantics), and the push-receipt callback that is the only path allowed to mark an
/// FCM row Delivered.
/// </summary>
public class PushFanOutTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Trigger_CreatesOneFcmAttemptPerGuardianRecipient()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamilyWithGuardians(db, guardianCount: 2);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());

        await handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var attempts = db.SosDeliveryAttempts.ToList();
        Assert.Equal(2, attempts.Count(a => a.Channel == AlertChannel.SignalR));
        Assert.Equal(2, attempts.Count(a => a.Channel == AlertChannel.Fcm));
    }

    [Fact]
    public async Task Dispatch_SendsToEveryRegisteredTokenForARecipient()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, recipientId) = await SeedSessionWithOneFcmAttempt(db);
        await SeedTokens(db, recipientId, "token-1", "token-2", "token-3");

        var pushSender = new Mock<IPushSender>();
        IReadOnlyList<string>? capturedTokens = null;
        pushSender
            .Setup(p => p.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .Callback<IReadOnlyList<string>, PushMessage, CancellationToken>((tokens, _, _) => capturedTokens = tokens)
            .ReturnsAsync(new PushSendResult(3, Array.Empty<string>()));
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), new NoOpSmsGateway(), pushSender.Object);

        await dispatcher.DispatchAsync(sessionId);

        pushSender.Verify(
            p => p.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()),
            Times.Once);
        Assert.NotNull(capturedTokens);
        Assert.Equal(3, capturedTokens!.Count);
        Assert.Contains("token-1", capturedTokens);
        Assert.Contains("token-2", capturedTokens);
        Assert.Contains("token-3", capturedTokens);
    }

    [Fact]
    public async Task Dispatch_MarksFcmQueuedNotDelivered()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, recipientId) = await SeedSessionWithOneFcmAttempt(db);
        await SeedTokens(db, recipientId, "token-1");

        var pushSender = new Mock<IPushSender>();
        pushSender
            .Setup(p => p.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PushSendResult(1, Array.Empty<string>()));
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), new NoOpSmsGateway(), pushSender.Object);

        await dispatcher.DispatchAsync(sessionId);

        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId && a.Channel == AlertChannel.Fcm));
        Assert.Equal(SosDeliveryStatus.Queued, attempt.Status);
        Assert.NotNull(attempt.QueuedAtUtc);
        Assert.Null(attempt.DeliveredAtUtc);
    }

    [Fact]
    public async Task Dispatch_MarksFcmFailedWhenTheSenderThrows()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, recipientId) = await SeedSessionWithOneFcmAttempt(db);
        await SeedTokens(db, recipientId, "token-1");

        var signalRRecipientId = Guid.NewGuid();
        db.Users.Add(new User { Id = signalRRecipientId, Email = $"guardian-{signalRRecipientId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            RecipientUserId = signalRRecipientId,
            Channel = AlertChannel.SignalR,
            Status = SosDeliveryStatus.NotAttempted,
        });
        await db.SaveChangesAsync();

        var pushSender = new Mock<IPushSender>();
        pushSender
            .Setup(p => p.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("simulated FCM failure"));
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), pushSender.Object);

        await dispatcher.DispatchAsync(sessionId);

        var fcmAttempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.Channel == AlertChannel.Fcm));
        Assert.Equal(SosDeliveryStatus.Failed, fcmAttempt.Status);
        Assert.False(string.IsNullOrWhiteSpace(fcmAttempt.FailureReason));

        var signalRAttempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.RecipientUserId == signalRRecipientId));
        Assert.Equal(SosDeliveryStatus.Queued, signalRAttempt.Status);
    }

    [Fact]
    public async Task Dispatch_SkipsARecipientWithNoRegisteredTokens()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _) = await SeedSessionWithOneFcmAttempt(db);

        var pushSender = new Mock<IPushSender>();
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), new NoOpSmsGateway(), pushSender.Object);

        await dispatcher.DispatchAsync(sessionId);

        pushSender.Verify(
            p => p.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()),
            Times.Never);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId && a.Channel == AlertChannel.Fcm));
        Assert.Equal(SosDeliveryStatus.Failed, attempt.Status);
        Assert.False(string.IsNullOrWhiteSpace(attempt.FailureReason));
    }

    [Fact]
    public async Task Register_UpsertsATokenWithoutDuplicating()
    {
        await using var db = _factory.CreateContext();
        var userId = await SeedUser(db);
        var handler = new RegisterDeviceTokenCommandHandler(db);

        await handler.Handle(new RegisterDeviceTokenCommand(userId, "token-1", DevicePlatform.Android));
        var firstSeenAt = db.UserDeviceTokens.Single(t => t.Token == "token-1").LastSeenAtUtc;
        await Task.Delay(5);
        await handler.Handle(new RegisterDeviceTokenCommand(userId, "token-1", DevicePlatform.Android));

        var rows = db.UserDeviceTokens.Where(t => t.Token == "token-1").ToList();
        var row = Assert.Single(rows);
        Assert.True(row.LastSeenAtUtc >= firstSeenAt);
    }

    [Fact]
    public async Task Register_KeepsOtherDevicesOfTheSameUser()
    {
        await using var db = _factory.CreateContext();
        var userId = await SeedUser(db);
        var handler = new RegisterDeviceTokenCommandHandler(db);

        await handler.Handle(new RegisterDeviceTokenCommand(userId, "token-phone", DevicePlatform.Android));
        await handler.Handle(new RegisterDeviceTokenCommand(userId, "token-tablet", DevicePlatform.Android));

        var rows = db.UserDeviceTokens.Where(t => t.UserId == userId).ToList();
        Assert.Equal(2, rows.Count);
        Assert.Contains(rows, t => t.Token == "token-phone");
        Assert.Contains(rows, t => t.Token == "token-tablet");
    }

    [Fact]
    public async Task Register_ReassignsATokenThatMovedToAnotherUser()
    {
        await using var db = _factory.CreateContext();
        var previousOwnerId = await SeedUser(db);
        var newOwnerId = await SeedUser(db);
        var handler = new RegisterDeviceTokenCommandHandler(db);

        await handler.Handle(new RegisterDeviceTokenCommand(previousOwnerId, "shared-token", DevicePlatform.Android));
        await handler.Handle(new RegisterDeviceTokenCommand(newOwnerId, "shared-token", DevicePlatform.Android));

        var row = Assert.Single(db.UserDeviceTokens.Where(t => t.Token == "shared-token"));
        Assert.Equal(newOwnerId, row.UserId);
    }

    [Fact]
    public async Task ConfirmPushReceipt_MarksTheRowDelivered()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, recipientId) = await SeedSessionWithOneFcmAttempt(db);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.DeliveryStatusChanged(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosDeliveryStatusChangedDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new ConfirmPushReceiptCommandHandler(db, new FamilyAuthorizationService(db), broadcast.Object);

        var result = await handler.Handle(new ConfirmPushReceiptCommand(recipientId, sessionId));

        Assert.True(result.Applied);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId && a.Channel == AlertChannel.Fcm));
        Assert.Equal(SosDeliveryStatus.Delivered, attempt.Status);
        Assert.NotNull(attempt.DeliveredAtUtc);
        broadcast.Verify(
            b => b.DeliveryStatusChanged(
                familyId,
                It.Is<IEnumerable<Guid>>(ids => ids.Contains(recipientId)),
                It.IsAny<SosDeliveryStatusChangedDto>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    private static async Task<Guid> SeedUser(ApplicationDbContext db)
    {
        var userId = Guid.NewGuid();
        db.Users.Add(new User { Id = userId, Email = $"user-{userId}@example.com", FullName = "User", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        return userId;
    }

    private static async Task SeedTokens(ApplicationDbContext db, Guid userId, params string[] tokens)
    {
        var now = DateTime.UtcNow;
        foreach (var token in tokens)
        {
            db.UserDeviceTokens.Add(new UserDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = DevicePlatform.Android,
                CreatedAtUtc = now,
                LastSeenAtUtc = now,
            });
        }

        await db.SaveChangesAsync();
    }

    private static async Task<(Guid FamilyId, Guid CallerId, Guid GuardianId)> SeedFamilyWithGuardians(ApplicationDbContext db, int guardianCount)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var lastGuardianId = Guid.Empty;

        db.Users.Add(new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Push Fan-out Family", CreatedByUserId = callerId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = callerId,
            Role = Role.Member,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });

        for (var i = 0; i < guardianCount; i++)
        {
            var guardianId = Guid.NewGuid();
            lastGuardianId = guardianId;
            db.Users.Add(new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = $"Guardian {i}", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
            db.FamilyMembers.Add(new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = guardianId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow,
                IsActive = true,
            });
        }

        await db.SaveChangesAsync();
        return (familyId, callerId, lastGuardianId);
    }

    private static async Task<(Guid FamilyId, Guid SosSessionId, Guid RecipientId)> SeedSessionWithOneFcmAttempt(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var triggeredByUserId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        db.Users.Add(new User { Id = triggeredByUserId, Email = $"sender-{triggeredByUserId}@example.com", FullName = "Sender", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Users.Add(new User { Id = recipientId, Email = $"guardian-{recipientId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Push Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });
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
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            RecipientUserId = recipientId,
            Channel = AlertChannel.Fcm,
            Status = SosDeliveryStatus.NotAttempted,
        });

        await db.SaveChangesAsync();
        return (familyId, sessionId, recipientId);
    }

    public void Dispose() => _factory.Dispose();
}
