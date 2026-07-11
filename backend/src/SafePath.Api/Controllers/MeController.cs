using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

public record UpdateMyRoleRequest(Role Role);

[ApiController]
[Route("me")]
[Authorize]
public class MeController : ControllerBase
{
    private readonly ICurrentUserService _currentUser;
    private readonly ICommandHandler<GetMeQuery, GetMeResult> _getMe;
    private readonly ICommandHandler<UpdateMyRoleCommand, GetMeResult> _updateMyRole;

    public MeController(
        ICurrentUserService currentUser,
        ICommandHandler<GetMeQuery, GetMeResult> getMe,
        ICommandHandler<UpdateMyRoleCommand, GetMeResult> updateMyRole)
    {
        _currentUser = currentUser;
        _getMe = getMe;
        _updateMyRole = updateMyRole;
    }

    [HttpGet]
    public async Task<ActionResult> Get(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _getMe.Handle(new GetMeQuery(userId), cancellationToken);

        return Ok(new
        {
            userId = result.UserId,
            role = result.Role?.ToString(),
            email = result.Email ?? User.FindFirstValue("email"),
            fullName = result.FullName,
            subject = User.FindFirstValue("sub"),
        });
    }

    [HttpPatch("role")]
    public async Task<ActionResult> UpdateRole([FromBody] UpdateMyRoleRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _updateMyRole.Handle(
            new UpdateMyRoleCommand(
                userId,
                request.Role,
                User.FindFirstValue("email"),
                User.FindFirstValue("name") ?? User.FindFirstValue("full_name")),
            cancellationToken);

        return Ok(new
        {
            userId = result.UserId,
            role = result.Role?.ToString(),
            email = result.Email ?? User.FindFirstValue("email"),
            fullName = result.FullName,
            subject = User.FindFirstValue("sub"),
        });
    }
}
