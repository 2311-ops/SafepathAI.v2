namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Provider-agnostic seam turning an SMS provider's raw delivery-status webhook payload into a
/// list of terminal status updates — keeps the provider's payload JSON shape entirely out of the
/// Application layer (same reasoning as <c>IInviteCodeGenerator</c> in the family feature).
/// Implemented in Infrastructure by <c>WhatsAppDeliveryStatusParser</c>. Only terminal outcomes
/// are modelled: an in-flight status (e.g. WhatsApp's <c>sent</c>) is simply not emitted, so the
/// handler has no "do nothing" branch to get wrong.
/// </summary>
public interface ISmsDeliveryStatusParser
{
    /// <summary>
    /// Parses <paramref name="rawBody"/> into zero or more terminal delivery-status updates.
    /// Never throws — a malformed or unrelated payload yields an empty list so an unparseable
    /// callback cannot 500 back at the provider and trigger its retry/disable behavior.
    /// </summary>
    IReadOnlyList<SmsDeliveryStatusUpdate> Parse(string rawBody);
}

/// <summary>A single terminal delivery-status update for one previously-sent message.</summary>
public record SmsDeliveryStatusUpdate(string ProviderMessageId, SmsDeliveryOutcome Outcome, string? FailureReason);

/// <summary>The two terminal outcomes a delivery-status callback can report.</summary>
public enum SmsDeliveryOutcome
{
    Delivered,
    Failed,
}
