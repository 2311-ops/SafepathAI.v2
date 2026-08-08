using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Infrastructure.Sms;

namespace SafePath.Api.Controllers;

/// <summary>
/// Twilio's (or any configured SMS provider's) delivery-status callback. This route
/// deliberately carries no authorization attribute -- the caller is the SMS provider, not an
/// authenticated user -- authenticity is established by recomputing the X-Twilio-Signature
/// header inside RecordSmsDeliveryStatusCommandHandler instead (threat T-03-19). No rate-limit
/// policy either: a single indexed lookup that no-ops on an unrecognised id is cheap, and a rate
/// limit here risks dropping a genuine delivery receipt, degrading delivery truthfulness for no
/// security gain (threat T-03-22, accepted).
/// </summary>
[ApiController]
public class SmsWebhookController : ControllerBase
{
    private readonly ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> _record;
    private readonly TwilioOptions _twilioOptions;

    public SmsWebhookController(
        ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> record,
        TwilioOptions twilioOptions)
    {
        _record = record;
        _twilioOptions = twilioOptions;
    }

    [HttpPost("webhooks/sms/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken)
    {
        var form = await Request.ReadFormAsync(cancellationToken);
        var parameters = form.Keys.ToDictionary(key => key, key => form[key].ToString());
        var signature = Request.Headers["X-Twilio-Signature"].ToString();
        var url = BuildValidatedUrl();

        var result = await _record.Handle(
            new RecordSmsDeliveryStatusCommand(url, parameters, string.IsNullOrEmpty(signature) ? null : signature),
            cancellationToken);

        if (!result.SignatureValid)
        {
            return Unauthorized();
        }

        return Ok();
    }

    /// <summary>
    /// Twilio signs the *public* URL it called (WR-02). Behind a TLS-terminating reverse proxy
    /// or load balancer without forwarded-header handling configured, <c>Request.Scheme</c>/
    /// <c>Request.Host</c> commonly report an internal scheme/host rather than what Twilio
    /// actually signed, which would fail every legitimate callback's signature check. Prefer the
    /// operator-configured public callback URL (<see cref="TwilioOptions.StatusCallbackUrl"/> --
    /// already known, since it is the exact URL <c>TwilioSmsGateway</c> tells Twilio to call
    /// back) plus the live query string, falling back to the request-derived URL only when no
    /// callback URL is configured (e.g. local dev with <c>LoggingSmsGateway</c>, where no real
    /// Twilio callback will ever arrive anyway).
    /// </summary>
    private string BuildValidatedUrl()
    {
        if (!string.IsNullOrWhiteSpace(_twilioOptions.StatusCallbackUrl))
        {
            return $"{_twilioOptions.StatusCallbackUrl}{Request.QueryString}";
        }

        return $"{Request.Scheme}://{Request.Host}{Request.Path}{Request.QueryString}";
    }
}
