using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Geofencing;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Infrastructure.Geofencing;

/// <summary>
/// Drains durable geofence routine-notification jobs in bounded batches. Each job receives a
/// fresh DI scope and DbContext so a provider failure cannot poison a sibling recipient's work.
/// This worker has no SOS dependency: emergency delivery remains on its own immediate path.
/// </summary>
public sealed class RoutinePushWorker : BackgroundService
{
    private const int BatchSize = 20;
    private static readonly TimeSpan DrainInterval = TimeSpan.FromMinutes(1);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<RoutinePushWorker> _logger;

    public RoutinePushWorker(
        IServiceScopeFactory scopeFactory,
        ILogger<RoutinePushWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>
    /// Processes one bounded batch using the supplied context. This is public to keep the
    /// identifier-only payload and retry semantics directly testable without starting a host.
    /// The hosted worker itself creates a fresh scope for every individual job.
    /// </summary>
    public static async Task<int> DrainDueJobsAsync(
        IApplicationDbContext db,
        RoutineNotificationDispatcher dispatcher,
        IRoutinePushSender sender,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var jobIds = await GetDueJobIdsAsync(db, nowUtc, cancellationToken);
        foreach (var jobId in jobIds)
        {
            try
            {
                await DispatchJobAsync(db, dispatcher, sender, jobId, nowUtc, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                await ScheduleRetryAsync(db, jobId, nowUtc, ex, cancellationToken);
            }
        }

        return jobIds.Count;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(DrainInterval);

        while (!stoppingToken.IsCancellationRequested)
        {
            await DrainWithFreshScopesAsync(stoppingToken);

            try
            {
                await timer.WaitForNextTickAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }

    private async Task DrainWithFreshScopesAsync(CancellationToken cancellationToken)
    {
        IReadOnlyList<Guid> jobIds;
        using (var discoveryScope = _scopeFactory.CreateScope())
        {
            var db = discoveryScope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
            jobIds = await GetDueJobIdsAsync(db, DateTime.UtcNow, cancellationToken);
        }

        foreach (var jobId in jobIds)
        {
            try
            {
                using var jobScope = _scopeFactory.CreateScope();
                var services = jobScope.ServiceProvider;
                var db = services.GetRequiredService<IApplicationDbContext>();
                var dispatcher = services.GetRequiredService<RoutineNotificationDispatcher>();
                var sender = services.GetRequiredService<IRoutinePushSender>();
                var nowUtc = DateTime.UtcNow;

                await DispatchJobAsync(db, dispatcher, sender, jobId, nowUtc, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                await ScheduleRetryInFreshScopeAsync(jobId, DateTime.UtcNow, ex, cancellationToken);
            }
        }
    }

    private async Task ScheduleRetryInFreshScopeAsync(
        Guid jobId,
        DateTime nowUtc,
        Exception exception,
        CancellationToken cancellationToken)
    {
        try
        {
            using var failureScope = _scopeFactory.CreateScope();
            var db = failureScope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
            await ScheduleRetryAsync(db, jobId, nowUtc, exception, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception retryException)
        {
            _logger.LogError(retryException, "Failed to schedule routine push job {JobId} for retry.", jobId);
        }
    }

    private static async Task<IReadOnlyList<Guid>> GetDueJobIdsAsync(
        IApplicationDbContext db,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        if (nowUtc.Kind != DateTimeKind.Utc)
        {
            throw new ArgumentException("UTC time is required.", nameof(nowUtc));
        }

        return await db.GeofenceRoutineJobs
            .Where(job => (job.State == GeofenceRoutineJobState.Pending || job.State == GeofenceRoutineJobState.DeferredForQuietHours)
                          && job.NextAttemptAtUtc <= nowUtc
                          && job.ExpiresAtUtc > nowUtc)
            .OrderBy(job => job.NextAttemptAtUtc)
            .ThenBy(job => job.CreatedAtUtc)
            .Take(BatchSize)
            .Select(job => job.Id)
            .ToListAsync(cancellationToken);
    }

    private static async Task DispatchJobAsync(
        IApplicationDbContext db,
        RoutineNotificationDispatcher dispatcher,
        IRoutinePushSender sender,
        Guid jobId,
        DateTime nowUtc,
        CancellationToken cancellationToken)
    {
        var quietHoursDecision = await dispatcher.ReevaluateAsync(jobId, nowUtc, cancellationToken);
        if (quietHoursDecision.State != RoutineNotificationDispatchState.SendNow)
        {
            return;
        }

        var job = await db.GeofenceRoutineJobs.SingleOrDefaultAsync(item => item.Id == jobId, cancellationToken)
            ?? throw new InvalidOperationException("Routine notification job no longer exists.");
        var feedItem = await db.GeofenceFeedItems.SingleOrDefaultAsync(item => item.Id == job.FeedItemId, cancellationToken)
            ?? throw new InvalidOperationException("Routine notification feed item no longer exists.");
        var activity = await db.GeofenceActivities.SingleOrDefaultAsync(item => item.Id == feedItem.ActivityId, cancellationToken)
            ?? throw new InvalidOperationException("Routine notification activity no longer exists.");
        var memberName = await db.Users
            .Where(user => user.Id == activity.MemberUserId)
            .Select(user => string.IsNullOrWhiteSpace(user.DisplayName) ? user.FullName : user.DisplayName!)
            .SingleOrDefaultAsync(cancellationToken);
        memberName = string.IsNullOrWhiteSpace(memberName) ? "A family member" : memberName;

        var tokenRows = await db.UserDeviceTokens
            .Where(token => token.UserId == job.RecipientUserId)
            .ToListAsync(cancellationToken);
        if (tokenRows.Count == 0)
        {
            throw new InvalidOperationException("No registered device token for this routine recipient.");
        }

        job.State = GeofenceRoutineJobState.Dispatching;
        job.LastAttemptAtUtc = nowUtc;
        job.AttemptCount++;
        job.LastFailureReason = null;
        await db.SaveChangesAsync(cancellationToken);

        var transitionText = activity.Transition == GeofenceTransition.Enter ? "entered" : "left";
        var title = $"{memberName} {transitionText} {activity.SafeZoneDisplayName}";
        var result = await sender.SendAsync(
            tokenRows.Select(token => token.Token).ToList(),
            new PushMessage(
                title,
                title,
                new Dictionary<string, string>
                {
                    ["type"] = "geofence",
                    ["activityId"] = activity.Id.ToString(),
                    ["zoneId"] = activity.SafeZoneId?.ToString() ?? string.Empty,
                }),
            cancellationToken);

        if (result.InvalidTokens.Count > 0)
        {
            db.UserDeviceTokens.RemoveRange(tokenRows.Where(token => result.InvalidTokens.Contains(token.Token)));
        }

        job.State = GeofenceRoutineJobState.Delivered;
        job.LastFailureReason = null;
        await db.SaveChangesAsync(cancellationToken);
    }

    private static async Task ScheduleRetryAsync(
        IApplicationDbContext db,
        Guid jobId,
        DateTime nowUtc,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var job = await db.GeofenceRoutineJobs.SingleOrDefaultAsync(item => item.Id == jobId, cancellationToken);
        if (job is null || job.ExpiresAtUtc <= nowUtc)
        {
            return;
        }

        var delayMinutes = Math.Min(30, Math.Pow(2, Math.Max(0, job.AttemptCount)));
        job.State = GeofenceRoutineJobState.Pending;
        job.NextAttemptAtUtc = nowUtc.AddMinutes(delayMinutes);
        job.LastFailureReason = exception.Message.Length > 512 ? exception.Message[..512] : exception.Message;
        await db.SaveChangesAsync(cancellationToken);
    }
}
