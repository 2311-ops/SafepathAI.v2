namespace SafePath.Domain.Enums;

/// <summary>
/// Delivery channel for one <see cref="Entities.SosDeliveryAttempt"/> row. A single recipient may
/// have multiple rows, one per channel — never a single collapsed sent flag (D-09, D-10).
/// </summary>
public enum AlertChannel
{
    SignalR,
    Fcm,
    Sms,
}
