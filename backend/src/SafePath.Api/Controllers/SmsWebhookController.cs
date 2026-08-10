using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

namespace SafePath.Api.Controllers;

/// <summary>
/// TextBee's (or any configured SMS provider's) delivery-status callback. This route is kept in
/// place structurally per product decision, though no real TextBee callback will ever arrive --
/// TextBee has no delivery-status webhook/callback mechanism. It deliberately carries no
/// authorization attribute -- the caller would be the SMS provider, not an authenticated user --
/// authenticity is established by delegating to <see cref="ISmsWebhookSignatureValidator"/>
/// (now <c>TextBeeWebhookSignatureValidator</c>, permanently false) rather than by recomputing a
/// provider-specific signature (threat T-VCF-02, formerly T-03-19). No rate-limit policy either: a
/// single indexed lookup that no-ops on an unrecognised id is cheap, and a rate limit here risks
/// dropping a genuine delivery receipt, degrading delivery truthfulness for no security gain
/// (threat T-03-22, accepted).
/// </summary>
[ApiController]
public class SmsWebhookController : ControllerBase
{
    private readonly ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> _record;

    public SmsWebhookController(
        ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> record)
    {
        _record = record;
    }

    [HttpPost("webhooks/sms/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken)
    {
        var form = await Request.ReadFormAsync(cancellationToken);
        var parameters = form.Keys.ToDictionary(key => key, key => form[key].ToString());
        // No SMS provider signature scheme is validated (TextBeeWebhookSignatureValidator is a
        // permanent no-op), so this header name is vestigial -- kept only because the request
        // pipeline still needs a signature value to pass through to the command.
        var signature = Request.Headers["X-Sms-Provider-Signature"].ToString();
        var url = $"{Request.Scheme}://{Request.Host}{Request.Path}{Request.QueryString}";

        var result = await _record.Handle(
            new RecordSmsDeliveryStatusCommand(url, parameters, string.IsNullOrEmpty(signature) ? null : signature),
            cancellationToken);

        if (!result.SignatureValid)
        {
            return Unauthorized();
        }

        return Ok();
    }
}
