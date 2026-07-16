namespace SafePath.Application.Location;

public static class GeoMath
{
    private const double EarthRadiusMeters = 6_371_000;

    public static double HaversineMeters(double lat1, double lng1, double lat2, double lng2)
    {
        var lat1Rad = ToRadians(lat1);
        var lat2Rad = ToRadians(lat2);
        var deltaLat = ToRadians(lat2 - lat1);
        var deltaLng = ToRadians(lng2 - lng1);

        var sinLat = Math.Sin(deltaLat / 2);
        var sinLng = Math.Sin(deltaLng / 2);
        var a = sinLat * sinLat +
            Math.Cos(lat1Rad) * Math.Cos(lat2Rad) * sinLng * sinLng;
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

        return EarthRadiusMeters * c;
    }

    private static double ToRadians(double degrees) => degrees * Math.PI / 180;
}
