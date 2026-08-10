namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Validates an inbound SMS-provider delivery-status webhook's signature before any mutation is
/// allowed to happen (threat T-03-19) — a forged callback must never be able to move a
/// <see cref="SafePath.Domain.Entities.SosDeliveryAttempt"/> row to Delivered. Kept in the
/// Application layer so no provider-specific crypto type ever appears there; implemented in
/// Infrastructure by <c>TextBeeWebhookSignatureValidator</c>, a permanent no-op since TextBee (or
/// any provider) has no delivery-status webhook to validate a signature for.
/// </summary>
public interface ISmsWebhookSignatureValidator
{
    /// <summary>
    /// Returns false (never throws) when the signature does not validate, or when no auth token
    /// is configured — in that latter case no legitimate provider callback can exist, so every
    /// request is refused outright rather than silently accepted.
    /// </summary>
    bool IsValid(string requestUrl, IReadOnlyDictionary<string, string> formParameters, string? signatureHeader);
}
