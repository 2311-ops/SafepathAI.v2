using SafePath.Application.Auth;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;

namespace SafePath.Application.Tests.Auth;

public class RegisterCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _dbFactory = new();
    private readonly BCryptPasswordHasher _hasher = new();
    private readonly JwtTokenGenerator _jwt = TestJwtTokenGeneratorFactory.Create();

    [Fact]
    public async Task Handle_ValidRegistration_PersistsHashedPasswordAndReturnsTokens()
    {
        using var db = _dbFactory.CreateContext();
        var handler = new RegisterCommandHandler(db, _hasher, _jwt);
        var command = new RegisterCommand("guardian@example.com", "CorrectHorseBattery1", "Jordan Guardian", Role.Guardian);

        var result = await handler.Handle(command, CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.False(string.IsNullOrWhiteSpace(result.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(result.RefreshToken));

        var persisted = db.Users.Single(u => u.Email == "guardian@example.com");
        Assert.NotEqual(command.Password, persisted.PasswordHash);
        Assert.True(_hasher.Verify(command.Password, persisted.PasswordHash));
        Assert.Equal(Role.Guardian, persisted.Role);
    }

    [Fact]
    public async Task Handle_DuplicateEmail_IsRejected()
    {
        using var db = _dbFactory.CreateContext();
        var handler = new RegisterCommandHandler(db, _hasher, _jwt);
        var command = new RegisterCommand("dup@example.com", "CorrectHorseBattery1", "Dup User", Role.Member);

        var first = await handler.Handle(command, CancellationToken.None);
        Assert.True(first.Succeeded);

        var second = await handler.Handle(command with { Password = "AnotherPassword2" }, CancellationToken.None);

        Assert.False(second.Succeeded);
        Assert.Single(db.Users.Where(u => u.Email == "dup@example.com"));
    }

    public void Dispose() => _dbFactory.Dispose();
}
