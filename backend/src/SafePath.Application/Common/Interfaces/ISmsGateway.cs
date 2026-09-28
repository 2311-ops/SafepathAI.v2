namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Provider-agnostic SMS seam — keeps the WhatsApp Business Cloud API (or any provider) entirely
/// out of the Application layer. Implemented in Infrastructure by <c>LoggingSmsGateway</c>
/// (zero-cost default) and <c>WhatsAppSmsGateway</c> (registered only when WhatsApp credentials
/// are configured).
/// </summary>
public interface ISmsGateway
{
    /// <summary>
    /// Sends a template message to <paramref name="toE164"/> using <paramref name="templateParameters"/>,
    /// an ordered list whose element order maps positionally to the configured template's body
    /// placeholders (index 0 -&gt; the first placeholder, index 1 -&gt; the second, and so on). The
    /// list's length is a property of the configured template, not of this seam — the gateway
    /// emits one parameter per supplied value and does not hard-code a count. Every element must
    /// be non-empty; WhatsApp Business templates are inherently multi-placeholder and Meta offers
    /// no way to omit a placeholder.
    ///
    /// This second parameter was previously a single composed <c>string</c> (locked by quick task
    /// 260812-wgl). That lock is deliberately superseded here: it was written before the
    /// operator's approved <c>sos_alert</c> template shape was known, under the assumption that a
    /// WhatsApp template could accept one free-text body parameter. It cannot — the approved
    /// template carries three separate body placeholders, and a single opaque string sent that way
    /// is rejected by Meta for a parameter-count mismatch. See quick task 260813-09i.
    ///
    /// A successful return means only that the provider accepted the message for delivery — never
    /// write <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Delivered"/> from this alone (D-10).
    /// </summary>
    Task<SmsSendResult> SendAsync(string toE164, IReadOnlyList<string> templateParameters, CancellationToken cancellationToken = default);
}

/// <summary>The provider's message id, used later to match an inbound delivery-status webhook.</summary>
public record SmsSendResult(string ProviderMessageId);
