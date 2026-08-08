namespace SafePath.Domain.Enums;

/// <summary>
/// Per-(recipient, channel) delivery state for an SOS alert. This is the exact five-state
/// vocabulary 03-UI-SPEC.md's Delivery Status Vocabulary renders.
/// </summary>
public enum SosDeliveryStatus
{
    NotAttempted,
    Queued,
    Delivered,
    Acknowledged,
    Failed,
}
