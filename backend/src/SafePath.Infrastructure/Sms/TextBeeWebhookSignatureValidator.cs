using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// TextBee has no delivery-status webhook/callback mechanism at all, and therefore no signature
/// scheme to validate (unlike the superseded Twilio design's <c>X-Twilio-Signature</c> /
/// <c>RequestValidator</c>). This is a permanent, documented no-op: <c>/webhooks/sms/status</c>
/// structurally refuses every request forever, including any forged one — the same refuse-by-
/// default posture <c>TwilioWebhookSignatureValidator</c> already had whenever no auth token was
/// configured, now permanently rather than only when unconfigured (threat T-VCF-02, formerly
/// T-03-19, stays closed by construction, not by configuration).
/// </summary>
public class TextBeeWebhookSignatureValidator : ISmsWebhookSignatureValidator
{
    public bool IsValid(string requestUrl, IReadOnlyDictionary<string, string> formParameters, string? signatureHeader) => false;
}
