using Moq;
using Microsoft.Extensions.Logging.Abstractions;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Geofencing;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Geofencing;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.Push;
using Xunit;

namespace SafePath.Application.Tests.Geofencing;

/// <summary>
/// Guards the routine-notification delivery boundary.  Routine pushes intentionally use a
/// separate sender seam so their normal-priority provider settings cannot leak into SOS.
/// </summary>
public sealed class RoutineNotificationDispatcherTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task LoggingRoutineSender_UsesTheRoutineOnlySeam()
    {
        var sender = new LoggingRoutinePushSender(
            NullLogger<LoggingRoutinePushSender>.Instance);
        var message = new PushMessage(
            "Sam entered Home",
            "Sam entered Home",
            new Dictionary<string, string>
            {
                ["type"] = "geofence",
                ["activityId"] = Guid.NewGuid().ToString(),
                ["zoneId"] = Guid.NewGuid().ToString(),
            });

        var result = await sender.SendAsync(new[] { "routine-token" }, message);

        Assert.False(typeof(IPushSender).IsAssignableFrom(typeof(IRoutinePushSender)));
        Assert.Equal(1, result.SuccessCount);
        Assert.Empty(result.InvalidTokens);
    }

    [Fact]
    public async Task DrainDueJobs_CompletesEligibleJobWithIdentifierOnlyRoutinePayload()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        var fixture = await SeedRoutineJobAsync(db, now, token: "routine-token");
        PushMessage? capturedMessage = null;
        var sender = new Mock<IRoutinePushSender>();
        sender
            .Setup(item => item.SendAsync(It.IsAny<IReadOnlyList<string>>(), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .Callback<IReadOnlyList<string>, PushMessage, CancellationToken>((_, message, _) => capturedMessage = message)
            .ReturnsAsync(new PushSendResult(1, Array.Empty<string>()));

        await RoutinePushWorker.DrainDueJobsAsync(
            db,
            new RoutineNotificationDispatcher(db),
            sender.Object,
            now);

        var job = await db.GeofenceRoutineJobs.FindAsync(fixture.JobId);
        Assert.NotNull(capturedMessage);
        Assert.Equal("Sam entered Home", capturedMessage!.Title);
        Assert.Equal("geofence", capturedMessage.Data["type"]);
        Assert.Equal(fixture.ActivityId.ToString(), capturedMessage.Data["activityId"]);
        Assert.Equal(fixture.ZoneId.ToString(), capturedMessage.Data["zoneId"]);
        Assert.DoesNotContain(capturedMessage.Data.Keys, key => key.Contains("latitude", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(capturedMessage.Data.Keys, key => key.Contains("longitude", StringComparison.OrdinalIgnoreCase));
        Assert.Equal(GeofenceRoutineJobState.Delivered, job!.State);
        Assert.NotNull(await db.GeofenceActivities.FindAsync(fixture.ActivityId));
        Assert.NotNull(await db.GeofenceFeedItems.FindAsync(fixture.FeedItemId));
    }

    [Fact]
    public async Task DrainDueJobs_KeepsFailingSiblingScheduledWhileCompletingEligibleSibling()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        var accepted = await SeedRoutineJobAsync(db, now, token: "accepted-token");
        var failing = await SeedRoutineJobAsync(db, now, token: "failing-token");
        var sender = new Mock<IRoutinePushSender>();
        sender
            .Setup(item => item.SendAsync(It.Is<IReadOnlyList<string>>(tokens => tokens.Contains("failing-token")), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("provider unavailable"));
        sender
            .Setup(item => item.SendAsync(It.Is<IReadOnlyList<string>>(tokens => tokens.Contains("accepted-token")), It.IsAny<PushMessage>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new PushSendResult(1, Array.Empty<string>()));

        await RoutinePushWorker.DrainDueJobsAsync(
            db,
            new RoutineNotificationDispatcher(db),
            sender.Object,
            now);

        var deliveredJob = await db.GeofenceRoutineJobs.FindAsync(accepted.JobId);
        var retryJob = await db.GeofenceRoutineJobs.FindAsync(failing.JobId);
        Assert.Equal(GeofenceRoutineJobState.Delivered, deliveredJob!.State);
        Assert.Equal(GeofenceRoutineJobState.Pending, retryJob!.State);
        Assert.True(retryJob.NextAttemptAtUtc > now);
        Assert.Equal("provider unavailable", retryJob.LastFailureReason);
        Assert.NotNull(await db.GeofenceActivities.FindAsync(failing.ActivityId));
        Assert.NotNull(await db.GeofenceFeedItems.FindAsync(failing.FeedItemId));
    }

    private static async Task<RoutineFixture> SeedRoutineJobAsync(ApplicationDbContext db, DateTime now, string token)
    {
        var suffix = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        var familyId = Guid.NewGuid();
        var zoneId = Guid.NewGuid();
        var activityId = Guid.NewGuid();
        var feedItemId = Guid.NewGuid();
        var jobId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{suffix:N}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberId, Email = $"member-{suffix:N}@example.com", FullName = "Member", DisplayName = "Sam", Role = Role.Member, CreatedAt = now });
        db.Families.Add(new Family { Id = familyId, Name = "Routine Jobs", CreatedByUserId = guardianId, CreatedAt = now });
        db.SafeZones.Add(new SafeZone
        {
            Id = zoneId,
            FamilyId = familyId,
            AssignedMemberUserId = memberId,
            CreatedByUserId = guardianId,
            Category = SafeZoneCategory.Home,
            Latitude = 30,
            Longitude = 31,
            RadiusMeters = 100,
            Sensitivity = SafeZoneSensitivity.Balanced,
            IsActive = true,
            CreatedAtUtc = now,
        });
        db.GeofenceActivities.Add(new GeofenceActivity
        {
            Id = activityId,
            SafeZoneId = zoneId,
            SafeZoneDisplayName = "Home",
            MemberUserId = memberId,
            Transition = GeofenceTransition.Enter,
            OccurredAtUtc = now,
            RecordedAtUtc = now,
            RetainUntilUtc = now.AddDays(7),
        });
        db.GeofenceFeedItems.Add(new GeofenceFeedItem
        {
            Id = feedItemId,
            ActivityId = activityId,
            RecipientUserId = guardianId,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(7),
        });
        db.GeofenceRoutineJobs.Add(new GeofenceRoutineJob
        {
            Id = jobId,
            FeedItemId = feedItemId,
            RecipientUserId = guardianId,
            State = GeofenceRoutineJobState.Pending,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(7),
        });
        db.UserDeviceTokens.Add(new UserDeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = guardianId,
            Token = token,
            Platform = DevicePlatform.Android,
            CreatedAtUtc = now,
            LastSeenAtUtc = now,
        });
        await db.SaveChangesAsync();

        return new RoutineFixture(jobId, feedItemId, activityId, zoneId);
    }

    private sealed record RoutineFixture(Guid JobId, Guid FeedItemId, Guid ActivityId, Guid ZoneId);

    public void Dispose() => _factory.Dispose();
}
