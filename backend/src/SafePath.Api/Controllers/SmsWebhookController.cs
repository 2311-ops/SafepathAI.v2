using System.Text;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

namespace SafePath.Api.Controllers;

/// <summary>
/// The WhatsApp Business Cloud API's (or any configured SMS provider's) delivery-status
/// callback, plus its subscription-handshake companion. This is a genuine, live callback path —
/// unlike the previously configured provider, this one delivers HMAC-signed sent/delivered/
/// read/failed status updates, so the SMS channel can now actually reach Delivered (D-10).
/// Both actions deliberately carry no authorization attribute — the caller is Meta, not an
/// authenticated user — authenticity is established by delegating to
/// <see cref="ISmsWebhookSignatureValidator"/> (now <c>WhatsAppWebhookSignatureValidator</c>,
/// which recomputes an HMAC-SHA256 over the raw body) rather than any ASP.NET Core auth scheme
/// (threat T-WGL-02). No rate-limit policy either: a single indexed lookup that no-ops on an
/// unrecognised id is cheap, and a rate limit here risks dropping a genuine delivery receipt,
/// degrading delivery truthfulness for no security gain (threat T-03-22, accepted).
/// </summary>
[ApiController]
public class SmsWebhookController : ControllerBase
{
    private readonly ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> _record;
    private readonly ISmsWebhookSignatureValidator _signatureValidator;

    public SmsWebhookController(
        ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult> record,
        ISmsWebhookSignatureValidator signatureValidator)
    {
        _record = record;
        _signatureValidator = signatureValidator;
    }

    [HttpPost("webhooks/sms/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken)
    {
        // The callback is JSON and its HMAC is computed over the exact bytes as received, so the
        // body must be read raw here — not model-bound or re-serialized — before validation.
        Request.EnableBuffering();
        string rawBody;
        using (var reader = new StreamReader(Request.Body, Encoding.UTF8, leaveOpen: true))
        {
            rawBody = await reader.ReadToEndAsync(cancellationToken);
        }

        var signature = Request.Headers["X-Hub-Signature-256"].ToString();

        var result = await _record.Handle(
            new RecordSmsDeliveryStatusCommand(rawBody, string.IsNullOrEmpty(signature) ? null : signature),
            cancellationToken);

        if (!result.SignatureValid)
        {
            return Unauthorized();
        }

        return Ok();
    }

    [HttpGet("webhooks/sms/status")]
    public IActionResult Verify(
        [FromQuery(Name = "hub.mode")] string? mode,
        [FromQuery(Name = "hub.verify_token")] string? verifyToken,
        [FromQuery(Name = "hub.challenge")] string? challenge)
    {
        if (mode == "subscribe" &&
            !string.IsNullOrEmpty(challenge) &&
            _signatureValidator.IsVerificationTokenValid(verifyToken))
        {
            return Content(challenge, "text/plain");
        }

        // Status-code form, not Forbid(), because this route has no authentication scheme for
        // Forbid() to challenge against.
        return StatusCode(StatusCodes.Status403Forbidden);
    }
}
