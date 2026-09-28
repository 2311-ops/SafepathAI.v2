using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// Guardian-owned circular safe-zone configuration. Native devices receive only the active
/// registration generation associated with their own assigned-member row.
/// </summary>
public sealed class SafeZone
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid AssignedMemberUserId { get; set; }
    public Guid CreatedByUserId { get; set; }
    public SafeZoneCategory Category { get; set; }
    public string? CustomName { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double RadiusMeters { get; set; }
    public SafeZoneSensitivity Sensitivity { get; set; }
    public bool NotifyAssignedMember { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsActive { get; set; } = true;
}

/// <summary>Guardian recipient configuration, normalized so recipient delivery can expand later.</summary>
public sealed class SafeZoneRecipient
{
    public Guid SafeZoneId { get; set; }
    public Guid RecipientUserId { get; set; }
}

/// <summary>
/// Server-issued native registration generation. Acknowledgement proves the assigned device
/// received this configuration; candidates must bind to the exact active generation.
/// </summary>
public sealed class SafeZoneRegistration
{
    public Guid Id { get; set; }
    public Guid SafeZoneId { get; set; }
    public Guid MemberUserId { get; set; }
    public int Generation { get; set; }
    public DateTime IssuedAtUtc { get; set; }
    public DateTime? AcknowledgedAtUtc { get; set; }
}

/// <summary>
/// Immutable native OS callback candidate. It is deliberately not an activity or notification:
/// Phase 04-07 owns dwell/accuracy confirmation and all routine delivery fan-out.
/// </summary>
public sealed class GeofenceCandidate
{
    public Guid Id { get; set; }
    public Guid EventId { get; set; }
    public Guid SafeZoneId { get; set; }
    public Guid MemberUserId { get; set; }
    public int RegistrationGeneration { get; set; }
    public GeofenceTransition Transition { get; set; }
    public DateTime OccurredAtUtc { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double AccuracyMeters { get; set; }
    public DateTime ReceivedAtUtc { get; set; }
}
