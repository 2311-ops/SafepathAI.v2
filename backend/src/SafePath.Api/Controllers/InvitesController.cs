using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;

namespace SafePath.Api.Controllers;

public record GenerateInviteRequest(string? InviteeLabel);

public record RedeemInviteRequest(string? Code, string? LinkToken, bool Accept);

[ApiController]
[Authorize]
public class InvitesController : ControllerBase
{
    private readonly ICommandHandler<GenerateInviteCommand, GenerateInviteResult> _generateInvite;
    private readonly ICommandHandler<RedeemInviteCommand, RedeemInviteResult> _redeemInvite;
    private readonly ICurrentUserService _currentUser;

    public InvitesController(
        ICommandHandler<GenerateInviteCommand, GenerateInviteResult> generateInvite,
        ICommandHandler<RedeemInviteCommand, RedeemInviteResult> redeemInvite,
        ICurrentUserService currentUser)
    {
        _generateInvite = generateInvite;
        _redeemInvite = redeemInvite;
        _currentUser = currentUser;
    }

    /// <summary>Guardian-only: generate a share-code/QR invite for a family (FAM-02).</summary>
    [HttpPost("families/{familyId:guid}/invites")]
    public async Task<ActionResult<GenerateInviteResult>> Generate(
        Guid familyId, [FromBody] GenerateInviteRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _generateInvite.Handle(
                new GenerateInviteCommand(userId, familyId, request.InviteeLabel), cancellationToken);
            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>Authenticated invitee accept/decline of a Pending invite (FAM-03). Rate-limited
    /// against code brute-forcing (RESEARCH Pitfall 4).</summary>
    [HttpPost("invites/redeem")]
    [EnableRateLimiting("invite-redeem")]
    public async Task<ActionResult<RedeemInviteResult>> Redeem(
        [FromBody] RedeemInviteRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _redeemInvite.Handle(
                new RedeemInviteCommand(userId, request.Code, request.LinkToken, request.Accept), cancellationToken);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}
