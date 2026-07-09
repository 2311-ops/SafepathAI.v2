namespace SafePath.Domain.Entities;

/// <summary>
/// A family circle — the root aggregate every Guardian/Member/Caregiver belongs to via a
/// <see cref="FamilyMember"/> row. Created by a Guardian (FAM-01); membership and invites are
/// scoped to a single <see cref="Family"/>.
/// </summary>
public class Family
{
    public Guid Id { get; set; }
    public string Name { get; set; } = default!;
    public Guid CreatedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
}
