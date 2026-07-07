using SafePath.Domain.Entities;

namespace SafePath.Application.Common.Interfaces;

public interface IJwtTokenGenerator
{
    /// <summary>Short-lived (20-minute) HMAC-SHA256-signed access token carrying sub + role claims.</summary>
    string GenerateAccessToken(User user);

    /// <summary>Cryptographically random (64-byte CSPRNG) refresh token, 7-day default expiry.</summary>
    (string Token, DateTime ExpiresAt) GenerateRefreshToken();
}
