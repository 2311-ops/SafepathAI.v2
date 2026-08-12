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
/// Covers SosAlertDispatcher's SignalR fan-out (Queued-not-Delivered semantics, per-channel
/// failure isolation) and TriggerSosCommandHandler's fire-and-forget wiring into it.
/// </summary>
public class AlertFanOutTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Dispatch_MarksSignalRAttemptsQueuedNotDelivered()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _) = await SeedTriggeredSession(db, recipientCount: 2);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        var attempts = db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId).ToList();
        Assert.Equal(2, attempts.Count);
        Assert.All(attempts, a =>
        {
            Assert.Equal(SosDeliveryStatus.Queued, a.Status);
            Assert.NotNull(a.QueuedAtUtc);
            Assert.Null(a.DeliveredAtUtc);
        });
    }

    [Fact]
    public async Task Dispatch_BroadcastsSosTriggeredToEveryResolvedRecipient()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, _, recipientIds) = await SeedTriggeredSession(db, recipientCount: 2);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        broadcast.Verify(
            b => b.SosTriggered(
                familyId,
                It.Is<IEnumerable<Guid>>(ids => new HashSet<Guid>(ids).SetEquals(recipientIds)),
                It.IsAny<SosSessionDto>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Dispatch_ExcludesTheTriggeringUser()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, triggeredByUserId, _) = await SeedTriggeredSession(db, recipientCount: 2);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        broadcast.Verify(
            b => b.SosTriggered(
                familyId,
                It.Is<IEnumerable<Guid>>(ids => !ids.Contains(triggeredByUserId)),
                It.IsAny<SosSessionDto>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task Dispatch_BroadcastsSendersPhoneNumberToTheRecipientAudienceOnlyAndExcludesTheSender()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, recipientIds) = await SeedTriggeredSession(db, recipientCount: 2, senderPhoneNumber: "+12025550173");
        SosSessionDto? captured = null;
        IEnumerable<Guid>? capturedRecipientIds = null;
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Callback<Guid, IEnumerable<Guid>, SosSessionDto, CancellationToken>((_, ids, dto, _) =>
            {
                captured = dto;
                capturedRecipientIds = ids;
            })
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        Assert.Equal("+12025550173", captured!.TriggeredByPhoneNumberE164);
        Assert.NotNull(capturedRecipientIds);
        Assert.DoesNotContain(triggeredByUserId, capturedRecipientIds!);
        Assert.True(new HashSet<Guid>(capturedRecipientIds!).SetEquals(recipientIds));
    }

    [Fact]
    public async Task Dispatch_ContinuesWhenOneChannelThrows()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _) = await SeedTriggeredSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("simulated channel failure"));
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, new NoOpSmsGateway(), new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId));
        Assert.Equal(SosDeliveryStatus.Failed, attempt.Status);
        Assert.False(string.IsNullOrWhiteSpace(attempt.FailureReason));
    }

    [Fact]
    public async Task Trigger_ReturnsBeforeDispatchCompletes()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamilyForTrigger(db);
        var neverCompletes = new TaskCompletionSource<object?>();
        var dispatcherMock = new Mock<ISosAlertDispatcher>();
        dispatcherMock
            .Setup(d => d.DispatchAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .Returns(neverCompletes.Task.ContinueWith(_ => { }));
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), dispatcherMock.Object);

        var handleTask = handler.Handle(new TriggerSosCommand(
            Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));
        var completed = await Task.WhenAny(handleTask, Task.Delay(TimeSpan.FromSeconds(2)));

        Assert.Same(handleTask, completed);
        Assert.False(neverCompletes.Task.IsCompleted);
        neverCompletes.TrySetResult(null);
    }

    [Fact]
    public async Task Dispatch_IsSkippedForAnIdempotentReplay()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamilyForTrigger(db);
        var dispatcherMock = new Mock<ISosAlertDispatcher>();
        dispatcherMock
            .Setup(d => d.DispatchAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), dispatcherMock.Object);
        var command = new TriggerSosCommand(Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow);

        await handler.Handle(command);
        await handler.Handle(command);

        dispatcherMock.Verify(d => d.DispatchAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    private async Task<(Guid FamilyId, Guid SosSessionId, Guid TriggeredByUserId, List<Guid> RecipientIds)> SeedTriggeredSession(
        ApplicationDbContext db,
        int recipientCount,
        string? senderPhoneNumber = null)
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
            PhoneNumberE164 = senderPhoneNumber,
            CreatedAt = DateTime.UtcNow,
        });
        db.Families.Add(new Family { Id = familyId, Name = "Fan-out Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });

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

    private static async Task<(Guid FamilyId, Guid CallerId, Guid GuardianId)> SeedFamilyForTrigger(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Trigger Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = callerId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });

        await db.SaveChangesAsync();
        return (familyId, callerId, guardianId);
    }

    public void Dispose() => _factory.Dispose();
}

/// <summary>
/// No-op ISmsGateway test double for tests that only exercise the SignalR arm — SmsFanOutTests.cs
/// covers the SMS arm itself.
/// </summary>
internal sealed class NoOpSmsGateway : ISmsGateway
{
    public Task<SmsSendResult> SendAsync(string toE164, IReadOnlyList<string> templateParameters, CancellationToken cancellationToken = default) =>
        Task.FromResult(new SmsSendResult($"noop-{Guid.NewGuid():N}"));
}

/// <summary>
/// No-op IPushSender test double for tests that only exercise the SignalR/SMS arms —
/// PushFanOutTests.cs covers the FCM arm itself.
/// </summary>
internal sealed class NoOpPushSender : IPushSender
{
    public Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default) =>
        Task.FromResult(new PushSendResult(tokens.Count, Array.Empty<string>()));
}
