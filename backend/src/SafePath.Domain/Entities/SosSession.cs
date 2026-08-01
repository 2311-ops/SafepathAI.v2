using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// A single SOS emergency, keyed by a client-issued <see cref="Id"/> (never server-generated,
/// D-13) so an offline retry storm can replay the same trigger idempotently (D-15) instead of
/// manufacturing duplicate emergencies. Independent of the routine location pipeline — nothing
/// here references <c>LocationPing</c> (SOS-01 structural isolation).
/// </summary>
public class SosSession
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid TriggeredByUserId { get; set; }
    public SosKind Kind { get; set; } = SosKind.Visible;
    public SosSessionStatus Status { get; set; } = SosSessionStatus.Active;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public double? AccuracyMeters { get; set; }
    public DateTime TriggeredAtUtc { get; set; }
    public DateTime ReceivedAtUtc { get; set; }
    public DateTime? LiveWindowEndsAtUtc { get; set; }
    public DateTime? CanceledAtUtc { get; set; }
    public Guid? CanceledByUserId { get; set; }
}
