using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// TextBee has no delivery-status webhook/callback mechanism at all, and therefore no signature
/// scheme to validate. This is a permanent, documented no-op: <c>/webhooks/sms/status</c>
/// structurally refuses every request forever, including any forged one — a refuse-by-default
/// posture applied unconditionally rather than only when a provider auth token happens to be
/// unconfigured (threat T-VCF-02, formerly T-03-19, stays closed by construction, not by
/// configuration).
/// </summary>
public class TextBeeWebhookSignatureValidator : ISmsWebhookSignatureValidator
{
    public bool IsValid(string requestUrl, IReadOnlyDictionary<string, string> formParameters, string? signatureHeader) => false;
}
