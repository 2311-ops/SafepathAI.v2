namespace SafePath.Application.Common.Interfaces;

public record LocationUpdateDto(
    Guid UserId,
    double Lat,
    double Lng,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc);

public record PresenceChangeDto(Guid UserId, bool IsOnline);
