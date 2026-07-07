namespace SafePath.Domain.Enums;

/// <summary>
/// Fixed family-circle role set (AUTH-05). Intentionally a small, closed enum — not a
/// dynamic/many-to-many role model — per locked decision D6.
/// </summary>
public enum Role
{
    Guardian,
    Member,
    Caregiver,
    OrgAdmin,
}
