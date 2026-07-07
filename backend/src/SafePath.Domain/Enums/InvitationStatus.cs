namespace SafePath.Domain.Enums;

/// <summary>
/// Family-invitation state machine. Not consumed by Phase 1's auth slice directly — created
/// now so the Phase 5 family-circle migration does not require a Domain edit.
/// </summary>
public enum InvitationStatus
{
    Pending,
    Accepted,
    Declined,
    Expired,
    Revoked,
}
