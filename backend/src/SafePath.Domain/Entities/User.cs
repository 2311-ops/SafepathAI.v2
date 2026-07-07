using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// Plain POCO user entity — deliberately not derived from any ASP.NET Core Identity base
/// class (locked decision D6). Only <see cref="PasswordHash"/> is ever persisted; the
/// plaintext password never reaches this layer.
/// </summary>
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = default!;
    public string PasswordHash { get; set; } = default!;
    public string FullName { get; set; } = default!;
    public Role Role { get; set; }
    public DateTime CreatedAt { get; set; }
}
