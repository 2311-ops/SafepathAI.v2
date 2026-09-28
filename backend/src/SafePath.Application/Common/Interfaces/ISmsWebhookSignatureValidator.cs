namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Validates an inbound SMS-provider delivery-status webhook's signature before any mutation is
/// allowed to happen (threat T-WGL-02, formerly T-03-19) — a forged callback must never be able
/// to move a <see cref="SafePath.Domain.Entities.SosDeliveryAttempt"/> row to Delivered. Kept in
/// the Application layer so no provider-specific crypto type ever appears there; implemented in
/// Infrastructure by <c>WhatsAppWebhookSignatureValidator</c>, which recomputes an HMAC-SHA256
/// over the exact raw request body.
/// </summary>
public interface ISmsWebhookSignatureValidator
{
    /// <summary>
    /// Returns false (never throws) when the signature does not validate, or when no app secret
    /// is configured — in that latter case no legitimate provider callback can exist, so every
    /// request is refused outright rather than silently accepted.
    /// </summary>
    bool IsValid(string rawBody, string? signatureHeader);

    /// <summary>
    /// Returns true only for an exact match against the configured subscription verify token,
    /// used to answer the provider's GET subscription handshake
    /// (<c>hub.mode</c>/<c>hub.verify_token</c>/<c>hub.challenge</c>). Returns false when no
    /// verify token is configured.
    /// </summary>
    bool IsVerificationTokenValid(string? verifyToken);
}
