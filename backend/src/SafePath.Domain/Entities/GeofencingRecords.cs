using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

public enum GeofenceConfirmationCandidateState
{
    Pending,
    Confirmed,
    Reset,
    Expired
}

/// <summary>
/// Server-owned, bounded confirmation state for a native callback. It is separate from the
/// immutable callback so drift resets and dwell evidence never rewrite the device event.
/// </summary>
public sealed class GeofenceConfirmationCandidate
{
    public Guid Id { get; set; }
    public Guid SafeZoneId { get; set; }
    public Guid MemberUserId { get; set; }
    public int RegistrationGeneration { get; set; }
    public GeofenceTransition IntendedTransition { get; set; }
    public GeofenceConfirmationCandidateState State { get; set; }
    public DateTime FirstObservedAtUtc { get; set; }
    public DateTime LastObservedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}

public enum SafeZoneRegistrationActivationState
{
    Pending,
    Active,
    Failed,
    Deactivated
}

/// <summary>
/// Captures whether a specific registration generation is active on its assigned device.
/// Acknowledgement alone is retained on the registration as the immutable receipt timestamp.
/// </summary>
public sealed class SafeZoneRegistrationActivation
{
    public Guid Id { get; set; }
    public Guid SafeZoneRegistrationId { get; set; }
    public SafeZoneRegistrationActivationState State { get; set; }
    public DateTime StateChangedAtUtc { get; set; }
    public string? FailureReason { get; set; }
}

/// <summary>
/// Durable confirmed transition history. Zone metadata is snapshotted so history and the
/// recipient feed remain readable if an operator later disables or deletes a zone.
/// </summary>
public sealed class GeofenceActivity
{
    public Guid Id { get; set; }
    public Guid? SafeZoneId { get; set; }
    public string SafeZoneDisplayName { get; set; } = string.Empty;
    public Guid MemberUserId { get; set; }
    public GeofenceTransition Transition { get; set; }
    public Guid? VisitId { get; set; }
    public int? CompletedVisitDurationSeconds { get; set; }
    public DateTime OccurredAtUtc { get; set; }
    public DateTime RecordedAtUtc { get; set; }
    public DateTime RetainUntilUtc { get; set; }
}

/// <summary>
/// Recipient-owned in-app notification row. It is written before push delivery is attempted.
/// </summary>
public sealed class GeofenceFeedItem
{
    public Guid Id { get; set; }
    public Guid ActivityId { get; set; }
    public Guid RecipientUserId { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? ReadAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
}

public enum GeofenceRoutineJobState
{
    Pending,
    DeferredForQuietHours,
    Dispatching,
    Delivered,
    Failed,
    Expired
}

/// <summary>
/// Durable routine-push work for one recipient feed row. It is intentionally unrelated to SOS
/// delivery records and can be retried or deferred without changing historical activity.
/// </summary>
public sealed class GeofenceRoutineJob
{
    public Guid Id { get; set; }
    public Guid FeedItemId { get; set; }
    public Guid RecipientUserId { get; set; }
    public GeofenceRoutineJobState State { get; set; }
    public int AttemptCount { get; set; }
    public DateTime NextAttemptAtUtc { get; set; }
    public DateTime? LastAttemptAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime ExpiresAtUtc { get; set; }
    public string? LastFailureReason { get; set; }
}

/// <summary>
/// A recipient's own routine-notification policy. Local wall-clock times and an IANA identifier
/// permit the dispatcher to calculate the next eligible UTC instant without involving SOS.
/// </summary>
public sealed class RecipientQuietHours
{
    public Guid Id { get; set; }
    public Guid RecipientUserId { get; set; }
    public bool IsEnabled { get; set; }
    public TimeOnly LocalStart { get; set; }
    public TimeOnly LocalEnd { get; set; }
    public string TimeZoneId { get; set; } = string.Empty;
    public DateTime UpdatedAtUtc { get; set; }
}
