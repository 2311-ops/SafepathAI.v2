using FluentValidation;
using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Common.Models;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Auth;

public record RegisterCommand(string Email, string Password, string FullName, Role Role);

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    public RegisterCommandValidator()
    {
        RuleFor(c => c.Email).NotEmpty().EmailAddress();
        RuleFor(c => c.Password).NotEmpty().MinimumLength(8);
        RuleFor(c => c.FullName).NotEmpty();
    }
}

/// <summary>
/// AUTH-01/AUTH-05: hashes the password (never persists plaintext), rejects duplicate
/// emails, persists the assigned Role, and returns a fresh access+refresh token pair.
/// </summary>
public class RegisterCommandHandler : ICommandHandler<RegisterCommand, AuthResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IPasswordHasher _hasher;
    private readonly IJwtTokenGenerator _jwt;

    public RegisterCommandHandler(IApplicationDbContext db, IPasswordHasher hasher, IJwtTokenGenerator jwt)
    {
        _db = db;
        _hasher = hasher;
        _jwt = jwt;
    }

    public async Task<AuthResult> Handle(RegisterCommand command, CancellationToken cancellationToken = default)
    {
        var normalizedEmail = command.Email.Trim().ToLowerInvariant();

        var alreadyExists = await _db.Users.AnyAsync(u => u.Email == normalizedEmail, cancellationToken);
        if (alreadyExists)
        {
            return AuthResult.Invalid("Email already registered");
        }

        var user = new User
        {
            Id = Guid.NewGuid(),
            Email = normalizedEmail,
            PasswordHash = _hasher.Hash(command.Password),
            FullName = command.FullName,
            Role = command.Role,
            CreatedAt = DateTime.UtcNow,
        };
        _db.Users.Add(user);

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
