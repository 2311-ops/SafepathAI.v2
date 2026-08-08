using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

/// <summary>
/// Per-device FCM token registration, and the FCM equivalent of <c>AlertHub.ConfirmReceipt</c>.
/// Every route derives the caller exclusively from <see cref="ICurrentUserService"/> — no
/// request body ever carries a user id.
/// </summary>
[ApiController]
[Authorize]
public class DeviceTokensController : ControllerBase
{
    private readonly ICommandHandler<RegisterDeviceTokenCommand, RegisterDeviceTokenResult> _register;
    private readonly ICommandHandler<RemoveDeviceTokenCommand, bool> _remove;
    private readonly ICommandHandler<ConfirmPushReceiptCommand, ConfirmPushReceiptResult> _confirmReceipt;
    private readonly ICurrentUserService _currentUser;

    public DeviceTokensController(
        ICommandHandler<RegisterDeviceTokenCommand, RegisterDeviceTokenResult> register,
        ICommandHandler<RemoveDeviceTokenCommand, bool> remove,
        ICommandHandler<ConfirmPushReceiptCommand, ConfirmPushReceiptResult> confirmReceipt,
        ICurrentUserService currentUser)
    {
        _register = register;
        _remove = remove;
        _confirmReceipt = confirmReceipt;
        _currentUser = currentUser;
    }

    [HttpPost("me/device-tokens")]
    public async Task<ActionResult<RegisterDeviceTokenResult>> Register(
        [FromBody] RegisterDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _register.Handle(
                new RegisterDeviceTokenCommand(userId, request.Token, request.Platform),
                cancellationToken);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpDelete("me/device-tokens")]
    public async Task<IActionResult> Remove(
        [FromBody] RemoveDeviceTokenRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        await _remove.Handle(new RemoveDeviceTokenCommand(userId, request.Token), cancellationToken);
        return NoContent();
    }

    [HttpPost("sos/{sosSessionId:guid}/push-receipt")]
    public async Task<IActionResult> ConfirmPushReceipt(Guid sosSessionId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            await _confirmReceipt.Handle(new ConfirmPushReceiptCommand(userId, sosSessionId), cancellationToken);
            return Ok();
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }
}

/// <summary>Request body for token registration — CallerUserId is never bound from here.</summary>
public record RegisterDeviceTokenRequest(string Token, DevicePlatform Platform);

/// <summary>Request body for token removal.</summary>
public record RemoveDeviceTokenRequest(string Token);
