namespace SafePath.Application.Geofencing;

public enum GeofenceEvidenceOutcome { Waiting, Reset, Confirmed, Duplicate }

public sealed record SubmitGeofenceEvidenceResult(GeofenceEvidenceOutcome Outcome);
