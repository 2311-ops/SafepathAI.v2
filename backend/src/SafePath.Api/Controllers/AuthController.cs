using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using SafePath.Application.Auth;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Common.Models;

namespace SafePath.Api.Controllers;

[ApiController]
[Route("auth")]
public class AuthController : ControllerBase
{
    private readonly ICommandHandler<RegisterCommand, AuthResult> _register;
    private readonly ICommandHandler<LoginCommand, AuthResult> _login;
    private readonly ICommandHandler<RefreshTokenCommand, AuthResult> _refresh;
    private readonly ICommandHandler<LogoutCommand, bool> _logout;

    public AuthController(
        ICommandHandler<RegisterCommand, AuthResult> register,
        ICommandHandler<LoginCommand, AuthResult> login,
        ICommandHandler<RefreshTokenCommand, AuthResult> refresh,
        ICommandHandler<LogoutCommand, bool> logout)
    {
        _register = register;
        _login = login;
        _refresh = refresh;
        _logout = logout;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResult>> Register(RegisterCommand command, CancellationToken cancellationToken)
    {
        var result = await _register.Handle(command, cancellationToken);
        return result.Succeeded ? Ok(result) : Conflict(result);
    }

    [HttpPost("login")]
    [EnableRateLimiting("login")]
    public async Task<ActionResult<AuthResult>> Login(LoginCommand command, CancellationToken cancellationToken)
    {
        var result = await _login.Handle(command, cancellationToken);
        return result.Succeeded ? Ok(result) : Unauthorized(result);
    }

    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResult>> Refresh(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        var result = await _refresh.Handle(command, cancellationToken);
        return result.Succeeded ? Ok(result) : Unauthorized(result);
    }

    [HttpPost("logout")]
    public async Task<IActionResult> Logout(LogoutCommand command, CancellationToken cancellationToken)
    {
        var succeeded = await _logout.Handle(command, cancellationToken);
        return succeeded ? Ok() : NotFound();
    }
}
