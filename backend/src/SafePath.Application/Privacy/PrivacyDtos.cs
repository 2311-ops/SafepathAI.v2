using SafePath.Domain.Enums;

namespace SafePath.Application.Privacy;

public record SharingPreferenceDto(
    Guid? RecipientMemberId,
    string? RecipientName,
    SharedDataType DataType,
    bool IsEnabled,
    DateTime? ExpiresAtUtc);

public record SharingMatrixDto(IReadOnlyList<SharingPreferenceDto> Entries);

public record ExportLocationPingDto(
    Guid Id,
    Guid UserId,
    double Lat,
    double Lng,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc,
    DateTime ReceivedAtUtc);

public record ExportSharingPreferenceDto(
    Guid Id,
    Guid FamilyId,
    Guid OwnerUserId,
    Guid? RecipientMemberId,
    SharedDataType DataType,
    bool IsEnabled,
    DateTime? ExpiresAtUtc);

public record MyDataExportDto(
    IReadOnlyList<ExportLocationPingDto> LocationPings,
    IReadOnlyList<ExportSharingPreferenceDto> SharingPreferences);

public record DeleteMyDataResult(int PingsDeleted);
