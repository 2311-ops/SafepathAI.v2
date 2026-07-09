using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Api.Controllers;

[ApiController]
[Route("me")]
[Authorize]
public class MeController : ControllerBase
{
    private readonly ICurrentUserService _currentUser;

    public MeController(ICurrentUserService currentUser)
    {
        _currentUser = currentUser;
    }

    [HttpGet]
    public ActionResult Get()
    {
        return Ok(new
        {
            userId = _currentUser.UserId,
            role = _currentUser.Role?.ToString(),
            email = User.FindFirstValue("email"),
            subject = User.FindFirstValue("sub"),
        });
    }
}
