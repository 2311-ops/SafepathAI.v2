using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Geofencing;

/// <summary>
/// Deletes expired geofence routine rows without touching safe-zone configuration, SOS, or
/// ordinary location history. The application query also enforces the same seven-day boundary
/// at read time, so this worker is storage cleanup rather than access control.
/// </summary>
public sealed class GeofenceRetentionService : BackgroundService
{
    private static readonly TimeSpan SweepInterval = TimeSpan.FromHours(6);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<GeofenceRetentionService> _logger;

    public GeofenceRetentionService(
        IServiceScopeFactory scopeFactory,
        ILogger<GeofenceRetentionService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public static async Task<int> SweepExpired(
        IApplicationDbContext db,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var expiredJobs = await db.GeofenceRoutineJobs
            .Where(job => job.ExpiresAtUtc < nowUtc)
            .ToListAsync(cancellationToken);
        var expiredFeedItems = await db.GeofenceFeedItems
            .Where(item => item.ExpiresAtUtc < nowUtc)
            .ToListAsync(cancellationToken);
        var expiredActivities = await db.GeofenceActivities
            .Where(activity => activity.RetainUntilUtc < nowUtc)
            .ToListAsync(cancellationToken);

        db.GeofenceRoutineJobs.RemoveRange(expiredJobs);
        db.GeofenceFeedItems.RemoveRange(expiredFeedItems);
        db.GeofenceActivities.RemoveRange(expiredActivities);

        var deleted = expiredJobs.Count + expiredFeedItems.Count + expiredActivities.Count;
        if (deleted > 0)
        {
            await db.SaveChangesAsync(cancellationToken);
        }

        return deleted;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(SweepInterval);

        while (!stoppingToken.IsCancellationRequested)
        {
            await RunSweep(stoppingToken);

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

    private async Task RunSweep(CancellationToken cancellationToken)
    {
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
            await SweepExpired(db, DateTime.UtcNow, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to sweep expired geofence activity.");
        }
    }
}
