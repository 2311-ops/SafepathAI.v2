using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// A user's membership in a single family circle — the row every family-scoped authorization
/// check (<see cref="Application.Common.Interfaces.IFamilyAuthorizationService"/>) re-verifies
/// server-side (IDOR prevention, locked decision D5). Soft-removable: <see cref="IsActive"/>
/// false and <see cref="RemovedAt"/> set means the user no longer has standing in the family,
/// but the historical row is retained.
/// </summary>
public class FamilyMember
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid UserId { get; set; }
    public Role Role { get; set; }
    public PermissionLevel Permissions { get; set; }
    public DateTime JoinedAt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime? RemovedAt { get; set; }
}
