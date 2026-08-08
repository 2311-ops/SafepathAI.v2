using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// Owner-scoped emergency contact view. Returned ONLY from EmergencyContactsController's
/// `/me/emergency-contacts` routes for the contact's own owning user — this is the single DTO
/// in the codebase carrying a phone number; never embed it in SosSessionDto/SosRecipientStatusDto
/// or any other guardian-facing payload (threat T-03-03).
/// </summary>
public record EmergencyContactDto(
    Guid Id,
    string DisplayName,
    string PhoneNumberE164,
    bool IsActive);

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
    IReadOnlyList<SosRecipientStatusDto> Recipients,
    /// <summary>
    /// The TRIGGERING user's own stored phone number, populated only when this payload's
    /// audience is contained in this session's distinct delivery-attempt recipient set
    /// (<see cref="SosSessionProjection"/>) — never to the triggering user themselves, and
    /// never to a family member who merely passed membership authorization without an
    /// actual delivery-attempt row. This is a different subject and audience from
    /// <see cref="SosRecipientStatusDto"/>, which remains untouched and still never carries
    /// a recipient's own contact details (T-03-03).
    /// </summary>
    string? TriggeredByPhoneNumberE164 = null);

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
