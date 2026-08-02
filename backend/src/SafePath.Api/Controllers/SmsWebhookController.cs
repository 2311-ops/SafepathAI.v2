using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

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

    public SmsWebhookController(ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> record)
    {
        _record = record;
    }

    [HttpPost("webhooks/sms/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken)
    {
        var form = await Request.ReadFormAsync(cancellationToken);
        var parameters = form.Keys.ToDictionary(key => key, key => form[key].ToString());
        var signature = Request.Headers["X-Twilio-Signature"].ToString();
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
