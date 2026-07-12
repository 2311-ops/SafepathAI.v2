using SafePath.Domain.Enums;

namespace SafePath.Application.Privacy;

public record SharingPreferenceDto(
    Guid? RecipientMemberId,
    string? RecipientName,
    SharedDataType DataType,
    bool IsEnabled,
    DateTime? ExpiresAtUtc);

public record SharingMatrixDto(IReadOnlyList<SharingPreferenceDto> Entries);
