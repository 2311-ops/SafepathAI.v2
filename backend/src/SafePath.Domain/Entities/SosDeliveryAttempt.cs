using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// One delivery row per (recipient, channel) pair for an <see cref="SosSession"/> — never a
/// single collapsed sent flag (D-09, D-10). Exactly one of <see cref="RecipientUserId"/> /
/// <see cref="EmergencyContactId"/> is set: in-app Guardians are reached via
/// <see cref="RecipientUserId"/>, contacts reached only by SMS via
/// <see cref="EmergencyContactId"/>.
/// </summary>
public class SosDeliveryAttempt
{
    public Guid Id { get; set; }
    public Guid SosSessionId { get; set; }
    public Guid? RecipientUserId { get; set; }
    public Guid? EmergencyContactId { get; set; }
    public AlertChannel Channel { get; set; }
    public SosDeliveryStatus Status { get; set; } = SosDeliveryStatus.NotAttempted;
    public DateTime? QueuedAtUtc { get; set; }
    public DateTime? DeliveredAtUtc { get; set; }
    public DateTime? AcknowledgedAtUtc { get; set; }
    public string? FailureReason { get; set; }
    public string? ProviderMessageId { get; set; }
}
