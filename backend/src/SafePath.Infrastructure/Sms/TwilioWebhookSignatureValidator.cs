using SafePath.Application.Common.Interfaces;
using Twilio.Security;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Wraps Twilio's <see cref="RequestValidator"/>, which recomputes the expected signature over
/// the full request URL plus the sorted form parameters using the configured auth token.
/// </summary>
public class TwilioWebhookSignatureValidator : ISmsWebhookSignatureValidator
{
    private readonly TwilioOptions _options;

    public TwilioWebhookSignatureValidator(TwilioOptions options)
    {
        _options = options;
    }

    public bool IsValid(string requestUrl, IReadOnlyDictionary<string, string> formParameters, string? signatureHeader)
    {
        if (string.IsNullOrWhiteSpace(_options.AuthToken) || string.IsNullOrEmpty(signatureHeader))
        {
            return false;
        }

        var validator = new RequestValidator(_options.AuthToken);
        return validator.Validate(requestUrl, new Dictionary<string, string>(formParameters), signatureHeader);
    }
}
