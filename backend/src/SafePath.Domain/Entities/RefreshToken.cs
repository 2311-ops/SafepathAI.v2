namespace SafePath.Domain.Entities;

/// <summary>
/// Server-side refresh-token state, enabling single-use rotation + revocation
/// (RESEARCH.md Architecture Patterns §2). Access tokens are stateless; refresh tokens
/// are the only auth state that must live in the database.
/// </summary>
public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Token { get; set; } = default!;
    public DateTime ExpiresAt { get; set; }
    public bool IsRevoked { get; set; }
    public Guid? ReplacedFrom { get; set; }
    public DateTime CreatedAt { get; set; }
}
