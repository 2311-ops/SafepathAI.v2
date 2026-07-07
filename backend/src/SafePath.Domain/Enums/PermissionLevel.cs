namespace SafePath.Domain.Enums;

/// <summary>
/// Per-member visibility level within a family circle. Not consumed by Phase 1's auth slice
/// directly — created now so the Phase 5 family-circle migration does not require a Domain edit.
/// </summary>
public enum PermissionLevel
{
    ViewOnly,
    FullLocation,
    NotificationOnly,
}
