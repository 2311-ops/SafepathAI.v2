using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Identity;

/// <summary>Verbatim from RESEARCH.md Code Examples — work factor 12 is the 2026 default.</summary>
public class BCryptPasswordHasher : IPasswordHasher
{
    public string Hash(string password) => BCrypt.Net.BCrypt.HashPassword(password, workFactor: 12);
    public bool Verify(string password, string hash) => BCrypt.Net.BCrypt.Verify(password, hash);
}
