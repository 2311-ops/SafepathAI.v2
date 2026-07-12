using SafePath.Application.Location;
using SafePath.Domain.Entities;
using Xunit;

namespace SafePath.Application.Tests.Location;

public class StopDetectionTests
{
    [Fact]
    public void DetectStops_DwellWithinDefaultRadiusForMinimumDuration_ProducesOneStop()
    {
        var start = DateTime.UtcNow.AddMinutes(-10);
        var pings = new[]
        {
            NewPing(30.0444, 31.2357, start),
            NewPing(30.0446, 31.2359, start.AddMinutes(2)),
            NewPing(30.0445, 31.2358, start.AddMinutes(5)),
        };

        var stops = StopDetection.DetectStops(pings);

        var stop = Assert.Single(stops);
        Assert.Equal(start, stop.StartUtc);
        Assert.Equal(start.AddMinutes(5), stop.EndUtc);
        Assert.InRange(stop.Latitude, 30.0444, 30.0446);
        Assert.InRange(stop.Longitude, 31.2357, 31.2359);
    }

    [Fact]
    public void DetectStops_MovementWithoutDwell_ProducesNoStops()
    {
        var start = DateTime.UtcNow.AddMinutes(-10);
        var pings = new[]
        {
            NewPing(30.0444, 31.2357, start),
            NewPing(30.0544, 31.2357, start.AddMinutes(2)),
            NewPing(30.0644, 31.2357, start.AddMinutes(4)),
            NewPing(30.0744, 31.2357, start.AddMinutes(6)),
        };

        var stops = StopDetection.DetectStops(pings);

        Assert.Empty(stops);
    }

    [Fact]
    public void DetectStops_TwoDwellClustersSeparatedByMovement_ProducesTwoStops()
    {
        var start = DateTime.UtcNow.AddMinutes(-20);
        var pings = new[]
        {
            NewPing(30.0444, 31.2357, start),
            NewPing(30.0445, 31.2358, start.AddMinutes(3)),
            NewPing(30.0446, 31.2359, start.AddMinutes(6)),
            NewPing(30.0644, 31.2357, start.AddMinutes(8)),
            NewPing(30.0645, 31.2358, start.AddMinutes(11)),
            NewPing(30.0646, 31.2359, start.AddMinutes(14)),
        };

        var stops = StopDetection.DetectStops(pings);

        Assert.Equal(2, stops.Count);
        Assert.Equal(start, stops[0].StartUtc);
        Assert.Equal(start.AddMinutes(6), stops[0].EndUtc);
        Assert.Equal(start.AddMinutes(8), stops[1].StartUtc);
        Assert.Equal(start.AddMinutes(14), stops[1].EndUtc);
    }

    [Fact]
    public void DetectStops_EmptyOrSinglePing_ReturnsEmptyWithoutThrowing()
    {
        Assert.Empty(StopDetection.DetectStops([]));
        Assert.Empty(StopDetection.DetectStops([NewPing(30.0444, 31.2357, DateTime.UtcNow)]));
    }

    private static LocationPing NewPing(double latitude, double longitude, DateTime recordedAt) => new()
    {
        Id = Guid.NewGuid(),
        UserId = Guid.NewGuid(),
        Latitude = latitude,
        Longitude = longitude,
        AccuracyMeters = 10,
        BatteryPercent = null,
        RecordedAtUtc = recordedAt,
        ReceivedAtUtc = recordedAt,
    };
}
