using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Auth;

public record LogoutCommand(string RefreshToken);

/// <summary>AUTH-03: revokes the presented refresh token so a later refresh with it fails.</summary>
public class LogoutCommandHandler : ICommandHandler<LogoutCommand, bool>
{
    private readonly IApplicationDbContext _db;

    public LogoutCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<bool> Handle(LogoutCommand command, CancellationToken cancellationToken = default)
    {
        var existing = await _db.RefreshTokens.SingleOrDefaultAsync(t => t.Token == command.RefreshToken, cancellationToken);
        if (existing is null)
        {
            return false;
        }

        existing.IsRevoked = true;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}
