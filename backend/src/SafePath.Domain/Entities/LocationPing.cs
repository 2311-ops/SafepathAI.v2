namespace SafePath.Domain.Entities;

/// <summary>
/// Raw append-only location report from a user device. Client time is retained separately
/// from server receipt time so stale-location UI and later history analysis can reason over both.
/// </summary>
public class LocationPing
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double AccuracyMeters { get; set; }
    public int? BatteryPercent { get; set; }
    public DateTime RecordedAtUtc { get; set; }
    public DateTime ReceivedAtUtc { get; set; }
}
