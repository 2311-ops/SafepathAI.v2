using SafePath.Application.Geofencing;
using SafePath.Domain.Entities;

namespace SafePath.Application.Tests.Geofencing;

public sealed class QuietHoursTests
{
    [Fact]
    public void DisabledSetting_SendsImmediately()
    {
        var nowUtc = new DateTime(2026, 3, 5, 23, 0, 0, DateTimeKind.Utc);

        var decision = RoutineNotificationDispatcher.Decide(new RecipientQuietHours
        {
            IsEnabled = false,
            LocalStart = new TimeOnly(22, 0),
            LocalEnd = new TimeOnly(7, 0),
            TimeZoneId = "Etc/UTC",
        }, nowUtc);

        Assert.Equal(RoutineNotificationDispatchState.SendNow, decision.State);
        Assert.Equal(nowUtc, decision.NextAttemptAtUtc);
    }

    [Fact]
    public void OvernightWindow_DefersUntilNextLocalEnd()
    {
        var nowUtc = new DateTime(2026, 3, 5, 23, 0, 0, DateTimeKind.Utc);

        var decision = RoutineNotificationDispatcher.Decide(new RecipientQuietHours
        {
            IsEnabled = true,
            LocalStart = new TimeOnly(22, 0),
            LocalEnd = new TimeOnly(7, 0),
            TimeZoneId = "Etc/UTC",
        }, nowUtc);

        Assert.Equal(RoutineNotificationDispatchState.DeferredForQuietHours, decision.State);
        Assert.Equal(new DateTime(2026, 3, 6, 7, 0, 0, DateTimeKind.Utc), decision.NextAttemptAtUtc);
    }

    [Fact]
    public void DstBoundary_DefersToTheNextValidLocalEnd()
    {
        var nowUtc = new DateTime(2026, 3, 8, 6, 30, 0, DateTimeKind.Utc); // 01:30 EST

        var decision = RoutineNotificationDispatcher.Decide(new RecipientQuietHours
        {
            IsEnabled = true,
            LocalStart = new TimeOnly(22, 0),
            LocalEnd = new TimeOnly(3, 0),
            TimeZoneId = "America/New_York",
        }, nowUtc);

        Assert.Equal(RoutineNotificationDispatchState.DeferredForQuietHours, decision.State);
        Assert.Equal(new DateTime(2026, 3, 8, 7, 0, 0, DateTimeKind.Utc), decision.NextAttemptAtUtc);
    }

    [Fact]
    public void InvalidZone_FailsClosedAsPending()
    {
        var nowUtc = new DateTime(2026, 3, 5, 23, 0, 0, DateTimeKind.Utc);

        var decision = RoutineNotificationDispatcher.Decide(new RecipientQuietHours
        {
            IsEnabled = true,
            LocalStart = new TimeOnly(22, 0),
            LocalEnd = new TimeOnly(7, 0),
            TimeZoneId = "Invalid/Zone",
        }, nowUtc);

        Assert.Equal(RoutineNotificationDispatchState.PendingInvalidTimeZone, decision.State);
        Assert.True(decision.NextAttemptAtUtc > nowUtc);
    }
}
