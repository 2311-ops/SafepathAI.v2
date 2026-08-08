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

    /// <summary>
    /// The owning user's own phone number in strict E.164 form, matching the
    /// <see cref="EmergencyContact.PhoneNumberE164"/> naming convention so the format
    /// invariant is visible at every read site. Nullable and unset by default — no signup,
    /// user-sync trigger, or family-join flow ever requires it. Reaches clients through
    /// exactly two doors: `/me` for the owning user, and a recipient-scoped SOS session
    /// payload (see SosSessionProjection) for that session's actual delivery recipients.
    /// </summary>
    public string? PhoneNumberE164 { get; set; }

    public DateTime? ProfileUpdatedAt { get; set; }
    public Role? Role { get; set; }
    public DateTime CreatedAt { get; set; }
}
