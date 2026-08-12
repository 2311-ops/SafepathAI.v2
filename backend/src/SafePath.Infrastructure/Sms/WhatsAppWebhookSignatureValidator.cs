using System.Security.Cryptography;
using System.Text;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Recomputes an HMAC-SHA256 over the raw inbound webhook request body, keyed with the
/// configured Meta app secret, and compares it against the <c>X-Hub-Signature-256</c> header in
/// fixed time (threat T-WGL-02). Refuses every request outright when no app secret is configured
/// — in that case no legitimate callback can exist. Also answers the subscription-handshake
/// verify-token check (<see cref="IsVerificationTokenValid"/>), compared the same fixed-time way.
/// </summary>
public class WhatsAppWebhookSignatureValidator : ISmsWebhookSignatureValidator
{
    private const string SignaturePrefix = "sha256=";

    private readonly WhatsAppOptions _options;

    public WhatsAppWebhookSignatureValidator(WhatsAppOptions options)
    {
        _options = options;
    }

    public bool IsValid(string rawBody, string? signatureHeader)
    {
        if (string.IsNullOrWhiteSpace(_options.AppSecret) || string.IsNullOrWhiteSpace(signatureHeader))
        {
            return false;
        }

        if (!signatureHeader.StartsWith(SignaturePrefix, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var providedHex = signatureHeader[SignaturePrefix.Length..];

        byte[] providedBytes;
        try
        {
            providedBytes = Convert.FromHexString(providedHex);
        }
        catch (FormatException)
        {
            return false;
        }

        var computedBytes = HMACSHA256.HashData(
            Encoding.UTF8.GetBytes(_options.AppSecret),
            Encoding.UTF8.GetBytes(rawBody));

        return CryptographicOperations.FixedTimeEquals(providedBytes, computedBytes);
    }

    public bool IsVerificationTokenValid(string? verifyToken)
    {
        if (string.IsNullOrWhiteSpace(_options.WebhookVerifyToken) || verifyToken is null)
        {
            return false;
        }

        var expectedBytes = Encoding.UTF8.GetBytes(_options.WebhookVerifyToken);
        var actualBytes = Encoding.UTF8.GetBytes(verifyToken);

        if (expectedBytes.Length != actualBytes.Length)
        {
            return false;
        }

        return CryptographicOperations.FixedTimeEquals(expectedBytes, actualBytes);
    }
}
