using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Common.Models;
using SafePath.Domain.Entities;

namespace SafePath.Application.Auth;

public record LoginCommand(string Email, string Password);

/// <summary>
/// AUTH-02: verifies credentials and issues a fresh access+refresh pair. Unknown email and
/// wrong password return the exact same <see cref="AuthResult.Invalid"/> result — never
/// reveal which field was wrong (enumeration-safe).
/// </summary>
public class LoginCommandHandler : ICommandHandler<LoginCommand, AuthResult>
{
    private const string InvalidCredentialsError = "Invalid email or password";

    private readonly IApplicationDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtTokenGenerator _jwt;

    public LoginCommandHandler(IApplicationDbContext db, IPasswordHasher hasher, IJwtTokenGenerator jwt)
    {
        _db = db;
        _hasher = hasher;
        _jwt = jwt;
    }

    public async Task<AuthResult> Handle(LoginCommand command, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();
        var user = await _db.Users.SingleOrDefaultAsync(u => u.Email == normalizedEmail, cancellationToken);

        if (user is null || !_hasher.Verify(command.Password, user.PasswordHash))
        {
            return AuthResult.Invalid(InvalidCredentialsError);
        }

        var accessToken = _jwt.GenerateAccessToken(user);
        var (refreshToken, expiresAt) = _jwt.GenerateRefreshToken();
        _db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = refreshToken,
            ExpiresAt = expiresAt,
            IsRevoked = false,
            CreatedAt = DateTime.UtcNow,
        });

        await _db.SaveChangesAsync(cancellationToken);

        return AuthResult.Success(accessToken, refreshToken);
    }
}
