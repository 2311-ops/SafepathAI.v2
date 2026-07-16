using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

/// <summary>
/// Auto-stops expired temporary sharing rows. Sensitive location traffic remains protected by
/// the existing ASP.NET HTTPS/WSS transport (`UseHttpsRedirection` and JWT
/// `RequireHttpsMetadata = true`); this service introduces no new cryptography.
/// </summary>
public class SharingPreferenceSweepService : BackgroundService
{
    private static readonly TimeSpan SweepInterval = TimeSpan.FromSeconds(60);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SharingPreferenceSweepService> _logger;

    public SharingPreferenceSweepService(
        IServiceScopeFactory scopeFactory,
        ILogger<SharingPreferenceSweepService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public static async Task<int> SweepExpired(
        IApplicationDbContext db,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        var expired = await db.SharingPreferences
            .Where(p => p.IsEnabled && p.ExpiresAtUtc <= nowUtc)
            .ToListAsync(cancellationToken);

        foreach (var preference in expired)
        {
            preference.IsEnabled = false;
        }

        if (expired.Count > 0)
        {
            await db.SaveChangesAsync(cancellationToken);
        }

        return expired.Count;
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
            _logger.LogError(ex, "Failed to sweep expired sharing preferences.");
        }
    }
}
