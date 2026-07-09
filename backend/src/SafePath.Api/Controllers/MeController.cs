using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;

namespace SafePath.Api.Controllers;

[ApiController]
[Route("me")]
[Authorize]
public class MeController : ControllerBase
{
    private readonly ICurrentUserService _currentUser;
    private readonly ICommandHandler<GetMeQuery, GetMeResult> _getMe;

    public MeController(ICurrentUserService currentUser, ICommandHandler<GetMeQuery, GetMeResult> getMe)
    {
        _currentUser = currentUser;
        _getMe = getMe;
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
}
