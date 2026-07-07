using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Common.Models;
using SafePath.Domain.Entities;

namespace SafePath.Application.Auth;

public record RefreshTokenCommand(string RefreshToken);

/// <summary>
/// AUTH-02: refresh-token rotation with reuse detection (RESEARCH.md Architecture Patterns
/// §2). Every refresh token is single-use — presenting an already-revoked token is treated
/// as a signal of theft and wipes every active refresh token for that user.
/// </summary>
public class RefreshTokenCommandHandler : ICommandHandler<RefreshTokenCommand, AuthResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IJwtTokenGenerator _jwt;

    public RefreshTokenCommandHandler(IApplicationDbContext db, IJwtTokenGenerator jwt)
    {
        _db = db;
        _jwt = jwt;
    }

    public async Task<AuthResult> Handle(RefreshTokenCommand command, CancellationToken cancellationToken = default)
    {
        var existing = await _db.RefreshTokens.SingleOrDefaultAsync(t => t.Token == command.RefreshToken, cancellationToken);
        if (existing is null)
        {
            return AuthResult.Invalid();
        }

        if (existing.IsRevoked)
        {
            // Reuse of a revoked token — assume compromise, nuke every active token for this user.
            await _db.RefreshTokens
                .Where(t => t.UserId == existing.UserId && !t.IsRevoked)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.IsRevoked, true), cancellationToken);
            return AuthResult.Invalid();
        }

        if (existing.ExpiresAt < DateTime.UtcNow)
        {
            return AuthResult.Invalid();
        }

        existing.IsRevoked = true;
        var (newToken, expiresAt) = _jwt.GenerateRefreshToken();
        _db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = existing.UserId,
            Token = newToken,
            ExpiresAt = expiresAt,
            IsRevoked = false,
            ReplacedFrom = existing.Id,
            CreatedAt = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync(cancellationToken);

        var user = await _db.Users.FindAsync([existing.UserId], cancellationToken);
        if (user is null)
        {
            return AuthResult.Invalid();
        }

        return AuthResult.Success(_jwt.GenerateAccessToken(user), newToken);
    }
}
