using SafePath.Application.Auth;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Auth;

public class LoginCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _dbFactory = new();
    private readonly BCryptPasswordHasher _hasher = new();
    private readonly JwtTokenGenerator _jwt = TestJwtTokenGeneratorFactory.Create();

    private async Task SeedUserAsync(ApplicationDbContext db, string email, string password)
    {
        var register = new RegisterCommandHandler(db, _hasher, _jwt);
        await register.Handle(new RegisterCommand(email, password, "Seed User", Role.Member), CancellationToken.None);
    }

    [Fact]
    public async Task Handle_CorrectCredentials_ReturnsAccessAndRefreshTokens()
    {
        using var db = _dbFactory.CreateContext();
        await SeedUserAsync(db, "login@example.com", "CorrectHorseBattery1");

        var handler = new LoginCommandHandler(db, _hasher, _jwt);
        var result = await handler.Handle(new LoginCommand("login@example.com", "CorrectHorseBattery1"), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(string.IsNullOrWhiteSpace(result.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(result.RefreshToken));
    }

    [Fact]
    public async Task Handle_UnknownEmailOrWrongPassword_ReturnsTheSameFailureResult()
    {
        using var db = _dbFactory.CreateContext();
        await SeedUserAsync(db, "known@example.com", "CorrectHorseBattery1");

        var handler = new LoginCommandHandler(db, _hasher, _jwt);

        var unknownEmailResult = await handler.Handle(new LoginCommand("nobody@example.com", "whatever123"), CancellationToken.None);
        var wrongPasswordResult = await handler.Handle(new LoginCommand("known@example.com", "wrong-password"), CancellationToken.None);

        Assert.False(unknownEmailResult.Succeeded);
        Assert.False(wrongPasswordResult.Succeeded);
        Assert.Equal(unknownEmailResult.Error, wrongPasswordResult.Error);
        Assert.Null(unknownEmailResult.AccessToken);
        Assert.Null(wrongPasswordResult.AccessToken);
    }

    public void Dispose() => _dbFactory.Dispose();
}
