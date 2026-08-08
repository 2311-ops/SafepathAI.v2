namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Binds <c>Twilio:AccountSid</c>, <c>Twilio:AuthToken</c>, <c>Twilio:FromNumber</c> and
/// <c>Twilio:StatusCallbackUrl</c> from configuration. Never committed — read from environment
/// / local secrets only (threat T-03-08). <see cref="IsConfigured"/> gates which <c>ISmsGateway</c>
/// implementation is registered: <c>LoggingSmsGateway</c> whenever any of the required three
/// values (SID, token, from-number) is missing, so a fresh clone builds/tests/demos with no
/// Twilio account and no spend (D-07).
/// </summary>
public class TwilioOptions
{
    public string? AccountSid { get; set; }
    public string? AuthToken { get; set; }
    public string? FromNumber { get; set; }

    /// <summary>
    /// Must be a publicly reachable HTTPS URL for Twilio's delivery-status callback (Task 3's
    /// <c>SmsWebhookController</c>). Leaving it unset simply means the SMS channel stays honestly
    /// at <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Queued"/> — never a wrong "Delivered".
    /// </summary>
    public string? StatusCallbackUrl { get; set; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(AccountSid) &&
        !string.IsNullOrWhiteSpace(AuthToken) &&
        !string.IsNullOrWhiteSpace(FromNumber);
}
