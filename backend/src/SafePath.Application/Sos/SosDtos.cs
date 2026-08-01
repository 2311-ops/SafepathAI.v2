using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// Per-channel delivery state for one recipient. Never a single collapsed sent flag (D-09).
/// </summary>
public record SosChannelStatusDto(
    AlertChannel Channel,
    SosDeliveryStatus Status,
    DateTime? QueuedAtUtc,
    DateTime? DeliveredAtUtc,
    DateTime? AcknowledgedAtUtc);

/// <summary>
/// One recipient's per-channel delivery state. Carries <see cref="DisplayName"/> only — no
/// phone number and no device token ever appears in a client-facing DTO (threat T-03-03).
/// </summary>
public record SosRecipientStatusDto(
    Guid? RecipientUserId,
    Guid? EmergencyContactId,
    string DisplayName,
    IReadOnlyList<SosChannelStatusDto> Channels);

/// <summary>
/// Full SOS emergency state returned by both POST /sos/trigger and GET /sos/{sosSessionId}.
/// </summary>
public record SosSessionDto(
    Guid SosSessionId,
    Guid FamilyId,
    Guid TriggeredByUserId,
    SosKind Kind,
    SosSessionStatus Status,
    DateTime TriggeredAtUtc,
    DateTime ReceivedAtUtc,
    DateTime? LiveWindowEndsAtUtc,
    DateTime? CanceledAtUtc,
    IReadOnlyList<SosRecipientStatusDto> Recipients);

/// <summary>
/// Pushed to the family alert group whenever a single (recipient, channel) delivery row's status
/// changes. Lets a connected client update one row of the delivery matrix without re-fetching the
/// whole session.
/// </summary>
public record SosDeliveryStatusChangedDto(
    Guid SosSessionId,
    Guid? RecipientUserId,
    Guid? EmergencyContactId,
    AlertChannel Channel,
    SosDeliveryStatus Status,
    DateTime AtUtc);

/// <summary>
/// Pushed to the family alert group when the triggering user cancels their own SOS session
/// (D-05, D-24). Cancellation is a parallel follow-up notice, never a retraction of the
/// original <see cref="SosSessionDto.Recipients"/> delivery history.
/// </summary>
public record SosCanceledDto(
    Guid SosSessionId,
    Guid CanceledByUserId,
    string CanceledByDisplayName,
    DateTime CanceledAtUtc);

/// <summary>
/// Live-location window update pushed during an active SOS session. Declared now so the
/// Infrastructure-layer IAlertClient contract is stable across this plan and plan 03-08 (which
/// is the first to actually populate it).
/// </summary>
public record SosLocationUpdateDto(
    Guid SosSessionId,
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    DateTime RecordedAtUtc,
    DateTime WindowEndsAtUtc);
