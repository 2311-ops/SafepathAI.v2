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
/// Covers the server-authoritative live window (D-21/SOS-04): the window is stamped from the
/// server's own receive time (never re-stamped by an idempotent replay), enforced on every
/// position report, restricted to the triggering user, and structurally isolated from the
/// routine location pipeline (T-03-09, T-03-27, T-03-28).
/// </summary>
public class SosLiveWindowTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Trigger_StampsTheWindowEndFromServerTime()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId, _) = await SeedFamily(db);
        var options = new SosLiveWindowOptions { LiveWindowMinutes = 15 };
        var handler = new TriggerSosCommandHandler(
            db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher(), liveWindowOptions: options);
        var sosSessionId = Guid.NewGuid();

        // A deliberately skewed client-supplied TriggeredAtUtc — the server must anchor the
        // window to its own receive time, not this value.
        var skewedTriggeredAtUtc = DateTime.UtcNow.AddMinutes(-3);
        var before = DateTime.UtcNow;
        var result = await handler.Handle(new TriggerSosCommand(
            sosSessionId, callerId, familyId, null, null, null, skewedTriggeredAtUtc));
        var after = DateTime.UtcNow;

        var session = await db.SosSessions.SingleAsync(s => s.Id == sosSessionId);
        Assert.NotNull(session.LiveWindowEndsAtUtc);
        Assert.InRange(session.LiveWindowEndsAtUtc!.Value, before.AddMinutes(15), after.AddMinutes(15));
        Assert.Equal(session.LiveWindowEndsAtUtc, result.Session.LiveWindowEndsAtUtc);
    }

    [Fact]
    public async Task ReportLocation_BroadcastsToTheSessionRecipients()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, recipientIds) = await SeedActiveSession(db, recipientCount: 2);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.LiveLocationWindowUpdate(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosLocationUpdateDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        var result = await handler.Handle(new ReportSosLocationCommand(
            sessionId, triggeredByUserId, 30.0444, 31.2357, 5.0, DateTime.UtcNow));

        Assert.Equal(ReportSosLocationOutcome.Accepted, result.Outcome);
        broadcast.Verify(
            b => b.LiveLocationWindowUpdate(
                It.IsAny<Guid>(),
                It.Is<IEnumerable<Guid>>(ids => new HashSet<Guid>(ids).SetEquals(recipientIds)),
                It.Is<SosLocationUpdateDto>(dto => dto.SosSessionId == sessionId && dto.Latitude == 30.0444 && dto.Longitude == 31.2357),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task ReportLocation_RejectsAfterTheWindowExpires()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedActiveSession(db, recipientCount: 1, windowEndsAtUtc: DateTime.UtcNow.AddMinutes(-1));
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        var result = await handler.Handle(new ReportSosLocationCommand(
            sessionId, triggeredByUserId, 30.0444, 31.2357, 5.0, DateTime.UtcNow));

        Assert.Equal(ReportSosLocationOutcome.WindowClosed, result.Outcome);
        broadcast.Verify(
            b => b.LiveLocationWindowUpdate(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosLocationUpdateDto>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ReportLocation_RejectsAfterCancellation()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedActiveSession(db, recipientCount: 1);
        var session = await db.SosSessions.SingleAsync(s => s.Id == sessionId);
        session.Status = SosSessionStatus.Canceled;
        session.CanceledAtUtc = DateTime.UtcNow;
        session.CanceledByUserId = triggeredByUserId;
        await db.SaveChangesAsync();
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        var result = await handler.Handle(new ReportSosLocationCommand(
            sessionId, triggeredByUserId, 30.0444, 31.2357, 5.0, DateTime.UtcNow));

        Assert.Equal(ReportSosLocationOutcome.WindowClosed, result.Outcome);
        broadcast.Verify(
            b => b.LiveLocationWindowUpdate(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosLocationUpdateDto>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ReportLocation_RejectsANonTriggeringUser()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, recipientIds) = await SeedActiveSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() => handler.Handle(new ReportSosLocationCommand(
            sessionId, recipientIds[0], 30.0444, 31.2357, 5.0, DateTime.UtcNow)));
    }

    [Fact]
    public async Task ReportLocation_RejectsOutOfRangeCoordinates()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedActiveSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        await Assert.ThrowsAsync<ArgumentException>(() => handler.Handle(new ReportSosLocationCommand(
            sessionId, triggeredByUserId, 91, 31.2357, 5.0, DateTime.UtcNow)));
    }

    [Fact]
    public async Task ReportLocation_WritesNoLocationPingRow()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, triggeredByUserId, _) = await SeedActiveSession(db, recipientCount: 1);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.LiveLocationWindowUpdate(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosLocationUpdateDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var handler = new ReportSosLocationCommandHandler(db, broadcast.Object);

        await handler.Handle(new ReportSosLocationCommand(
            sessionId, triggeredByUserId, 30.0444, 31.2357, 5.0, DateTime.UtcNow));

        Assert.Empty(db.LocationPings);
    }

    private static async Task<(Guid FamilyId, Guid CallerId, Guid RecipientId)> SeedFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();

        db.Users.Add(new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Live Window Family", CreatedByUserId = callerId, CreatedAt = DateTime.UtcNow });
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

        await db.SaveChangesAsync();
        return (familyId, callerId, recipientId);
    }

    private static async Task<(Guid FamilyId, Guid SosSessionId, Guid TriggeredByUserId, List<Guid> RecipientIds)> SeedActiveSession(
        ApplicationDbContext db,
        int recipientCount,
        DateTime? windowEndsAtUtc = null)
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
        db.Families.Add(new Family { Id = familyId, Name = "Live Window Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });
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
            LiveWindowEndsAtUtc = windowEndsAtUtc ?? DateTime.UtcNow.AddMinutes(15),
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
