using SafePath.Application.Geofencing;
using SafePath.Domain.Enums;

namespace SafePath.Application.Tests.Geofencing;

public sealed class GeofenceTransitionEvaluatorTests
{
    private static readonly DateTime Now = new(2026, 8, 14, 0, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(SafeZoneSensitivity.Conservative, 120, 50)]
    [InlineData(SafeZoneSensitivity.Balanced, 60, 30)]
    [InlineData(SafeZoneSensitivity.Responsive, 30, 15)]
    public void Sensitivity_UsesCalibratedDwellAndHysteresis(SafeZoneSensitivity sensitivity, int dwellSeconds, int hysteresisMeters)
    {
        var calibration = GeofenceTransitionEvaluator.GetCalibration(sensitivity);

        Assert.Equal(TimeSpan.FromSeconds(dwellSeconds), calibration.DwellDuration);
        Assert.Equal(hysteresisMeters, calibration.HysteresisMeters);
    }

    [Fact]
    public void ClearInside_EvidenceStartsAndThenConfirmsOnlyAfterContiguousDwell()
    {
        var first = Evaluate(GeofenceTransition.Enter, Now, latitude: 0.0002, accuracyMeters: 5);
        var beforeDwell = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(59), latitude: 0.0002, accuracyMeters: 5, first.State);
        var confirmed = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(60), latitude: 0.0002, accuracyMeters: 5, first.State);

        Assert.Equal(GeofenceEvaluationOutcome.Waiting, first.Outcome);
        Assert.Equal(GeofenceEvaluationOutcome.Waiting, beforeDwell.Outcome);
        Assert.Equal(GeofenceEvaluationOutcome.Confirmed, confirmed.Outcome);
    }

    [Fact]
    public void BoundaryOverlappingAccuracy_WaitsWithoutAccumulatingDwell()
    {
        var first = Evaluate(GeofenceTransition.Enter, Now, latitude: 0.0002, accuracyMeters: 5);
        var ambiguous = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(30), latitude: 0.00075, accuracyMeters: 20, first.State);
        var restarted = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(60), latitude: 0.0002, accuracyMeters: 5, ambiguous.State);

        Assert.Equal(GeofenceEvaluationOutcome.Waiting, ambiguous.Outcome);
        Assert.Null(ambiguous.State.FirstClearSideObservedAtUtc);
        Assert.Equal(GeofenceEvaluationOutcome.Waiting, restarted.Outcome);
    }

    [Fact]
    public void ClearOppositeSide_ResetsPendingTransition()
    {
        var first = Evaluate(GeofenceTransition.Enter, Now, latitude: 0.0002, accuracyMeters: 5);
        var reset = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(30), latitude: 0.002, accuracyMeters: 5, first.State);

        Assert.Equal(GeofenceEvaluationOutcome.Reset, reset.Outcome);
        Assert.Null(reset.State.FirstClearSideObservedAtUtc);
    }

    [Fact]
    public void OutOfOrderEvidence_ResetsRatherThanExtendingDwell()
    {
        var first = Evaluate(GeofenceTransition.Enter, Now, latitude: 0.0002, accuracyMeters: 5);
        var outOfOrder = Evaluate(GeofenceTransition.Enter, Now.AddSeconds(-1), latitude: 0.0002, accuracyMeters: 5, first.State);

        Assert.Equal(GeofenceEvaluationOutcome.Reset, outOfOrder.Outcome);
        Assert.Null(outOfOrder.State.FirstClearSideObservedAtUtc);
    }

    [Fact]
    public void Exit_RequiresClearOutsideEnvelope()
    {
        var result = Evaluate(GeofenceTransition.Exit, Now, latitude: 0.0015, accuracyMeters: 5);

        Assert.Equal(GeofenceEvaluationOutcome.Waiting, result.Outcome);
        Assert.NotNull(result.State.FirstClearSideObservedAtUtc);
    }

    private static GeofenceEvaluationResult Evaluate(
        GeofenceTransition intendedTransition,
        DateTime occurredAtUtc,
        double latitude,
        double accuracyMeters,
        GeofenceTransitionState? state = null) =>
        GeofenceTransitionEvaluator.Evaluate(
            new GeofenceTransitionEvidence(
                intendedTransition,
                occurredAtUtc,
                latitude,
                0,
                accuracyMeters),
            new GeofenceZoneGeometry(0, 0, 100, SafeZoneSensitivity.Balanced),
            state ?? GeofenceTransitionState.Empty,
            Now.AddMinutes(1));
}
