using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// An FCM push token registered by a user's device. A user may legitimately hold several rows
/// across their devices (D-32 multi-device model) — this is not a one-token-per-user model.
/// </summary>
public class UserDeviceToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Token { get; set; } = default!;
    public DevicePlatform Platform { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime LastSeenAtUtc { get; set; }
}
