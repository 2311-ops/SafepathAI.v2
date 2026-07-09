using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// An expiring, single-use share-code/QR invitation into a family circle (locked decision D3 —
/// share-code/QR only, no required email field). <see cref="Code"/> is a short human-readable
/// display/manual-entry code; <see cref="LinkToken"/> is a longer opaque CSPRNG token carried by
/// the shareable link/QR payload (RESEARCH Pitfall 4 — the code alone is not the security
/// boundary).
/// </summary>
public class FamilyInvitation
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public string Code { get; set; } = default!;
    public string LinkToken { get; set; } = default!;
    public string? InviteeLabel { get; set; }
    public string? InviteeEmail { get; set; }
    public Guid CreatedByUserId { get; set; }
    public DateTime ExpiresAt { get; set; }
    public InvitationStatus Status { get; set; }
    public Guid? AcceptedByUserId { get; set; }
}
