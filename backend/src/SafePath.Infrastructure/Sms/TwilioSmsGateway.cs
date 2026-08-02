using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;
using Twilio.Clients;
using Twilio.Rest.Api.V2010.Account;
using Twilio.Types;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Twilio-backed <see cref="ISmsGateway"/> implementation, registered only when
/// <see cref="TwilioOptions.IsConfigured"/> is true. Passes <see cref="TwilioOptions.StatusCallbackUrl"/>
/// so Twilio reports delivery back to <c>SmsWebhookController</c> (plan Task 3) — a successful
/// return here means only that Twilio accepted the message, never that it was delivered (D-10).
/// </summary>
public class TwilioSmsGateway : ISmsGateway
{
    private readonly ITwilioRestClient _client;
    private readonly TwilioOptions _options;
    private readonly ILogger<TwilioSmsGateway> _logger;

    public TwilioSmsGateway(ITwilioRestClient client, TwilioOptions options, ILogger<TwilioSmsGateway> logger)
    {
        _client = client;
        _options = options;
        _logger = logger;
    }

    public async Task<SmsSendResult> SendAsync(string toE164, string body, CancellationToken cancellationToken = default)
    {
        try
        {
            var createOptions = new CreateMessageOptions(new PhoneNumber(toE164))
            {
                From = new PhoneNumber(_options.FromNumber),
                Body = body,
            };

            if (!string.IsNullOrWhiteSpace(_options.StatusCallbackUrl))
            {
                createOptions.StatusCallback = new Uri(_options.StatusCallbackUrl);
            }

            var message = await MessageResource.CreateAsync(createOptions, client: _client);
            return new SmsSendResult(message.Sid);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Do not surface the SDK's raw exception message up through the dispatcher's
            // FailureReason column — it can echo request details. Log the full exception here
            // (server-side only) and translate to a short, credential-free message.
            _logger.LogError(ex, "TwilioSmsGateway failed to send an SMS.");
            throw new InvalidOperationException("Failed to send SMS via the configured provider.", ex);
        }
    }
}
