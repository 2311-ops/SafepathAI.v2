using SafePath.Domain.Constants;
using SafePath.Domain.Entities;

namespace SafePath.Application.Location;

public record Stop(DateTime StartUtc, DateTime EndUtc, double Latitude, double Longitude);

public static class StopDetection
{
    public static IReadOnlyList<Stop> DetectStops(
        IReadOnlyList<LocationPing> pings,
        double? radiusMeters = null,
        TimeSpan? minDwell = null)
    {
        if (pings.Count < 2)
        {
            return [];
        }

        var radius = radiusMeters ?? DwellTimeDefaults.RadiusMeters;
        var dwell = minDwell ?? DwellTimeDefaults.MinDwell;
        var ordered = pings.OrderBy(p => p.RecordedAtUtc).ToList();
        var stops = new List<Stop>();
        var cluster = new List<LocationPing> { ordered[0] };
        var anchor = ordered[0];

        for (var i = 1; i < ordered.Count; i++)
        {
            var ping = ordered[i];
            var distanceFromAnchor = GeoMath.HaversineMeters(
                anchor.Latitude,
                anchor.Longitude,
                ping.Latitude,
                ping.Longitude);

            if (distanceFromAnchor <= radius)
            {
                cluster.Add(ping);
                continue;
            }

            AddStopIfDwelled(cluster, dwell, stops);
            cluster = [ping];
            anchor = ping;
        }

        AddStopIfDwelled(cluster, dwell, stops);
        return stops;
    }

    private static void AddStopIfDwelled(
        IReadOnlyList<LocationPing> cluster,
        TimeSpan minDwell,
        ICollection<Stop> stops)
    {
        if (cluster.Count < 2)
        {
            return;
        }

        var start = cluster[0].RecordedAtUtc;
        var end = cluster[^1].RecordedAtUtc;
        if (end - start < minDwell)
        {
            return;
        }

        stops.Add(new Stop(
            start,
            end,
            cluster.Average(p => p.Latitude),
            cluster.Average(p => p.Longitude)));
    }
}
