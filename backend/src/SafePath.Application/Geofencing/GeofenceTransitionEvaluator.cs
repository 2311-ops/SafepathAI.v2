using SafePath.Application.Location;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

/// <summary>
/// Pure, server-owned accuracy-envelope and contiguous-dwell evaluator. Persistence owns the
/// state between calls; this type deliberately has no database, clock, or delivery dependency.
/// </summary>
public static class GeofenceTransitionEvaluator
{
    private static readonly IReadOnlyDictionary<SafeZoneSensitivity, GeofenceTransitionCalibration> Calibrations =
        new Dictionary<SafeZoneSensitivity, GeofenceTransitionCalibration>
        {
            [SafeZoneSensitivity.Conservative] = new(TimeSpan.FromSeconds(120), 50),
            [SafeZoneSensitivity.Balanced] = new(TimeSpan.FromSeconds(60), 30),
            [SafeZoneSensitivity.Responsive] = new(TimeSpan.FromSeconds(30), 15),
        };

    public static GeofenceTransitionCalibration GetCalibration(SafeZoneSensitivity sensitivity) =>
        Calibrations.TryGetValue(sensitivity, out var calibration)
            ? calibration
            : throw new ArgumentOutOfRangeException(nameof(sensitivity));

    public static GeofenceEvaluationResult Evaluate(
        GeofenceTransitionEvidence evidence,
        GeofenceZoneGeometry zone,
        GeofenceTransitionState state,
        DateTime nowUtc)
    {
        if (!IsValid(evidence, zone, nowUtc) || IsOutOfOrder(evidence, state))
        {
            return Reset();
        }

        var calibration = GetCalibration(zone.Sensitivity);
        var distanceMeters = GeoMath.HaversineMeters(zone.Latitude, zone.Longitude, evidence.Latitude, evidence.Longitude);
        var isClearlyInside = distanceMeters + evidence.AccuracyMeters <= zone.RadiusMeters - calibration.HysteresisMeters;
        var isClearlyOutside = distanceMeters - evidence.AccuracyMeters >= zone.RadiusMeters + calibration.HysteresisMeters;
        var expectedClearSide = evidence.IntendedTransition == GeofenceTransition.Enter ? isClearlyInside : isClearlyOutside;
        var oppositeClearSide = evidence.IntendedTransition == GeofenceTransition.Enter ? isClearlyOutside : isClearlyInside;

        if (oppositeClearSide || (state.IntendedTransition is not null && state.IntendedTransition != evidence.IntendedTransition))
        {
            return Reset();
        }

        if (!expectedClearSide)
        {
            // Accuracy overlap is neither proof of a transition nor a durable reset event, but it
            // must discard accumulated clear-side dwell so boundary drift cannot confirm later.
            return new GeofenceEvaluationResult(GeofenceEvaluationOutcome.Waiting, GeofenceTransitionState.Empty);
        }

        var firstClearSideAtUtc = state.FirstClearSideObservedAtUtc ?? evidence.OccurredAtUtc;
        var nextState = new GeofenceTransitionState(evidence.IntendedTransition, firstClearSideAtUtc, evidence.OccurredAtUtc);
        return evidence.OccurredAtUtc - firstClearSideAtUtc >= calibration.DwellDuration
            ? new GeofenceEvaluationResult(GeofenceEvaluationOutcome.Confirmed, nextState)
            : new GeofenceEvaluationResult(GeofenceEvaluationOutcome.Waiting, nextState);
    }

    private static bool IsValid(GeofenceTransitionEvidence evidence, GeofenceZoneGeometry zone, DateTime nowUtc) =>
        nowUtc.Kind == DateTimeKind.Utc &&
        evidence.OccurredAtUtc.Kind == DateTimeKind.Utc &&
        evidence.OccurredAtUtc <= nowUtc.AddMinutes(5) &&
        double.IsFinite(evidence.Latitude) && evidence.Latitude is >= -90 and <= 90 &&
        double.IsFinite(evidence.Longitude) && evidence.Longitude is >= -180 and <= 180 &&
        double.IsFinite(evidence.AccuracyMeters) && evidence.AccuracyMeters >= 0 &&
        double.IsFinite(zone.Latitude) && zone.Latitude is >= -90 and <= 90 &&
        double.IsFinite(zone.Longitude) && zone.Longitude is >= -180 and <= 180 &&
        double.IsFinite(zone.RadiusMeters) && zone.RadiusMeters > 0;

    private static bool IsOutOfOrder(GeofenceTransitionEvidence evidence, GeofenceTransitionState state) =>
        state.LastObservedAtUtc is not null && evidence.OccurredAtUtc <= state.LastObservedAtUtc;

    private static GeofenceEvaluationResult Reset() =>
        new(GeofenceEvaluationOutcome.Reset, GeofenceTransitionState.Empty);
}

public sealed record GeofenceTransitionCalibration(TimeSpan DwellDuration, double HysteresisMeters);

public sealed record GeofenceZoneGeometry(double Latitude, double Longitude, double RadiusMeters, SafeZoneSensitivity Sensitivity);

public sealed record GeofenceTransitionEvidence(
    GeofenceTransition IntendedTransition,
    DateTime OccurredAtUtc,
    double Latitude,
    double Longitude,
    double AccuracyMeters);

public sealed record GeofenceTransitionState(
    GeofenceTransition? IntendedTransition,
    DateTime? FirstClearSideObservedAtUtc,
    DateTime? LastObservedAtUtc)
{
    public static GeofenceTransitionState Empty { get; } = new(null, null, null);
}

public enum GeofenceEvaluationOutcome { Waiting, Reset, Confirmed }

public sealed record GeofenceEvaluationResult(GeofenceEvaluationOutcome Outcome, GeofenceTransitionState State);
