using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// Plain POCO user entity — deliberately not derived from any ASP.NET Core Identity base
/// class (locked decision D6). Rows are populated by a Postgres trigger mirroring
/// Supabase Auth's <c>auth.users</c> on sign-up (see migration
/// SyncSupabaseUsersAndDropLegacyAuthColumns); the app never inserts into this table
/// directly, and no password material is stored here — Supabase Auth owns credentials.
/// </summary>
public class User
{
    public Guid Id { get; set; }
    public string Email { get; set; } = default!;
    public string FullName { get; set; } = default!;
    public string? DisplayName { get; set; }
    public string? ProfileImagePath { get; set; }
    public DateTime? ProfileUpdatedAt { get; set; }
    public Role? Role { get; set; }
    public DateTime CreatedAt { get; set; }
}
