namespace SafePath.Application.Location;

public record LocationUpdateDto(
    Guid UserId,
    double Lat,
    double Lng,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc);

public record PresenceChangeDto(Guid UserId, bool IsOnline);

public record LowBatteryAlertDto(Guid UserId, string? DisplayName, int BatteryPercent);

public record ProfileUpdateDto(Guid UserId, string? DisplayName, string? ProfileImageUrl);

public record MemberLiveLocationDto(
    Guid UserId,
    string? DisplayName,
    double? Lat,
    double? Lng,
    double? AccuracyMeters,
    int? BatteryPercent,
    DateTime? RecordedAtUtc,
    bool IsOnline,
    string? ProfileImageUrl);

public record LocationHistoryPointDto(double Lat, double Lng, DateTime RecordedAtUtc);

public record LocationHistoryDto(
    IReadOnlyList<LocationHistoryPointDto> PolylinePoints,
    IReadOnlyList<Stop> Stops);

/// <summary>
/// Travel summary for a bounded history range. TimeAway is defined as the elapsed time
/// between the first and last ping in the range, or zero when fewer than two pings exist.
/// </summary>
public record TravelStatsDto(double TotalDistanceMeters, TimeSpan TimeAway, int StopCount);
