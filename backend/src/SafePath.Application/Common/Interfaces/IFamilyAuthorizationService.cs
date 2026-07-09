using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Thrown when a caller fails a <see cref="IFamilyAuthorizationService"/> check — no active
/// membership in the family, or an insufficient role. Family-scoped API endpoints translate this
/// into a 403 response. Never trust a client-supplied familyId or role claim (IDOR prevention,
/// locked decision D5) — every family-scoped handler must call one of these checks itself.
/// </summary>
public class FamilyAuthorizationDeniedException : Exception
{
    public FamilyAuthorizationDeniedException(string message) : base(message)
    {
    }
}

/// <summary>
/// Server-side membership + role re-check used by every family-scoped Application handler.
/// This is the primary authorization enforcement mechanism (locked decision D5) — not Postgres
/// RLS, since the backend connects to Supabase with a trusted service-role connection string
/// that would bypass RLS if relied on alone (RESEARCH Pitfall 5).
/// </summary>
public interface IFamilyAuthorizationService
{
    /// <summary>
    /// Returns the caller's own active <see cref="FamilyMember"/> row for <paramref name="familyId"/>.
    /// Throws <see cref="FamilyAuthorizationDeniedException"/> if the caller has no active
    /// membership in that family.
    /// </summary>
    Task<FamilyMember> RequireMembership(Guid userId, Guid familyId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Returns the caller's own active <see cref="FamilyMember"/> row for <paramref name="familyId"/>
    /// when it also has <paramref name="role"/>. Throws <see cref="FamilyAuthorizationDeniedException"/>
    /// otherwise (no membership, or membership with a different role).
    /// </summary>
    Task<FamilyMember> RequireRole(Guid userId, Guid familyId, Role role, CancellationToken cancellationToken = default);
}
