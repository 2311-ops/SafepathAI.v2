using SafePath.Application.Auth;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Auth;

public class RefreshTokenCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _dbFactory = new();
    private readonly BCryptPasswordHasher _hasher = new();
    private readonly JwtTokenGenerator _jwt = TestJwtTokenGeneratorFactory.Create();

    private async Task<(ApplicationDbContext Db, string RefreshToken, Guid UserId)> SeedRegisteredUserAsync()
    {
        var db = _dbFactory.CreateContext();
        var register = new RegisterCommandHandler(db, _hasher, _jwt);
        var result = await register.Handle(
            new RegisterCommand("refresh@example.com", "CorrectHorseBattery1", "Refresh User", Role.Member),
            CancellationToken.None);
        var user = db.Users.Single(u => u.Email == "refresh@example.com");
        return (db, result.RefreshToken!, user.Id);
    }

    [Fact]
    public async Task Handle_ValidToken_IsRotatedSingleUse()
    {
        var (db, oldToken, userId) = await SeedRegisteredUserAsync();
        using var _ = db;
        var handler = new RefreshTokenCommandHandler(db, _jwt);

        var result = await handler.Handle(new RefreshTokenCommand(oldToken), CancellationToken.None);

        Assert.True(result.Succeeded);
        Assert.NotEqual(oldToken, result.RefreshToken);

        var oldRow = db.RefreshTokens.Single(t => t.Token == oldToken);
        Assert.True(oldRow.IsRevoked);

        var newRow = db.RefreshTokens.Single(t => t.Token == result.RefreshToken);
        Assert.False(newRow.IsRevoked);
        Assert.Equal(userId, newRow.UserId);
    }

    [Fact]
    public async Task Handle_ReuseOfRevokedToken_WipesAllActiveTokensForUser()
    {
        var (db, oldToken, userId) = await SeedRegisteredUserAsync();
        using var _ = db;
        var handler = new RefreshTokenCommandHandler(db, _jwt);

        var first = await handler.Handle(new RefreshTokenCommand(oldToken), CancellationToken.None);
        Assert.True(first.Succeeded);

        // Reuse of the now-revoked oldToken signals compromise.
        var reuse = await handler.Handle(new RefreshTokenCommand(oldToken), CancellationToken.None);

        Assert.False(reuse.Succeeded);

        // ExecuteUpdateAsync writes straight to the database, bypassing the change tracker,
        // so re-query through a fresh context (same underlying SQLite connection) rather than
        // `db` — otherwise EF's identity map would return the stale, already-tracked instance.
        using var verifyDb = _dbFactory.CreateContext();
        var allTokensForUser = verifyDb.RefreshTokens.Where(t => t.UserId == userId).ToList();
        Assert.All(allTokensForUser, t => Assert.True(t.IsRevoked));
    }

    public void Dispose() => _dbFactory.Dispose();
}
