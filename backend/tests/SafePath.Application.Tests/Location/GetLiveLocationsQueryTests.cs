using Microsoft.EntityFrameworkCore;
using SafePath.Application.Location;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Constants;
using SafePath.Domain.Entities;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class LocationFoundationTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public void HaversineMeters_ForNearbyMeridianPoints_IsWithinOnePercent()
    {
        var distance = GeoMath.HaversineMeters(30.0444, 31.2357, 30.0454, 31.2357);

        Assert.InRange(distance, 110, 113);
    }

    [Fact]
    public async Task LocationPing_RoundTripsThroughSqliteContext_ByUserAndRecordedAt()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var recordedAt = DateTime.UtcNow.AddMinutes(-2);

        db.LocationPings.Add(new LocationPing
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 14.2,
            BatteryPercent = 86,
            RecordedAtUtc = recordedAt,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var loaded = await db.LocationPings.SingleAsync(p =>
            p.UserId == userId &&
            p.RecordedAtUtc >= recordedAt.AddSeconds(-1) &&
            p.RecordedAtUtc <= recordedAt.AddSeconds(1));

        Assert.Equal(userId, loaded.UserId);
        Assert.Equal(30.0444, loaded.Latitude);
        Assert.Equal(31.2357, loaded.Longitude);
        Assert.Equal(14.2, loaded.AccuracyMeters);
        Assert.Equal(86, loaded.BatteryPercent);
    }

    [Fact]
    public void DwellTimeDefaults_ExposePhaseTwoStopThresholds()
    {
        Assert.Equal(100, DwellTimeDefaults.RadiusMeters);
        Assert.Equal(TimeSpan.FromMinutes(5), DwellTimeDefaults.MinDwell);
    }

    public void Dispose() => _factory.Dispose();
}
