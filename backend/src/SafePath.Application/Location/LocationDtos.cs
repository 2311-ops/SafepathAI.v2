namespace SafePath.Application.Location;

public record LocationUpdateDto(
    Guid UserId,
    double Lat,
    double Lng,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc);

public record PresenceChangeDto(Guid UserId, bool IsOnline);

public record MemberLiveLocationDto(
    Guid UserId,
    string? DisplayName,
    double? Lat,
    double? Lng,
    double? AccuracyMeters,
    int? BatteryPercent,
    DateTime? RecordedAtUtc,
    bool IsOnline);
