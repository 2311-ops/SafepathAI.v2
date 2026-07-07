using SafePath.Application.Auth;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;

namespace SafePath.Application.Tests.Auth;

public class LogoutCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _dbFactory = new();
    private readonly BCryptPasswordHasher _hasher = new();
    private readonly JwtTokenGenerator _jwt = TestJwtTokenGeneratorFactory.Create();

    [Fact]
    public async Task Handle_Logout_RevokesRefreshTokenSoSubsequentRefreshFails()
    {
        using var db = _dbFactory.CreateContext();
        var register = new RegisterCommandHandler(db, _hasher, _jwt);
        var registerResult = await register.Handle(
            new RegisterCommand("logout@example.com", "CorrectHorseBattery1", "Logout User", Role.Member),
            CancellationToken.None);

        var logoutHandler = new LogoutCommandHandler(db);
        var logoutResult = await logoutHandler.Handle(new LogoutCommand(registerResult.RefreshToken!), CancellationToken.None);

        Assert.True(logoutResult);

        var refreshHandler = new RefreshTokenCommandHandler(db, _jwt);
        var refreshAfterLogout = await refreshHandler.Handle(new RefreshTokenCommand(registerResult.RefreshToken!), CancellationToken.None);

        Assert.False(refreshAfterLogout.Succeeded);
    }

    public void Dispose() => _dbFactory.Dispose();
}
