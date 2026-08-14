using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;

namespace SafePath.Application.Geofencing;

/// <summary>
/// Re-evaluates recipient-owned quiet hours before a routine job is dispatched. This type
/// deliberately has no dependency on SOS dispatching or a push sender: it only determines
/// whether the durable job is ready or deferred.
/// </summary>
public sealed class RoutineNotificationDispatcher
{
    private readonly IApplicationDbContext _db;

    public RoutineNotificationDispatcher(IApplicationDbContext db) => _db = db;

    public async Task<RoutineNotificationDispatchDecision> ReevaluateAsync(
        Guid jobId,
        DateTime nowUtc,
        CancellationToken cancellationToken = default)
    {
        if (jobId == Guid.Empty || nowUtc.Kind != DateTimeKind.Utc)
            throw new ArgumentException("A job id and UTC time are required.");

        var job = await _db.GeofenceRoutineJobs.SingleOrDefaultAsync(item => item.Id == jobId, cancellationToken)
            ?? throw new ArgumentException("Routine notification job was not found.", nameof(jobId));
        var setting = await _db.RecipientQuietHours.SingleOrDefaultAsync(
            item => item.RecipientUserId == job.RecipientUserId,
            cancellationToken);
        var decision = Decide(setting, nowUtc);
        job.NextAttemptAtUtc = decision.NextAttemptAtUtc;
        job.State = decision.State switch
        {
            RoutineNotificationDispatchState.DeferredForQuietHours => GeofenceRoutineJobState.DeferredForQuietHours,
            RoutineNotificationDispatchState.PendingInvalidTimeZone => GeofenceRoutineJobState.Pending,
            _ => GeofenceRoutineJobState.Pending,
        };
        job.LastFailureReason = decision.State == RoutineNotificationDispatchState.PendingInvalidTimeZone
            ? "Quiet-hours time zone could not be resolved."
            : null;
        await _db.SaveChangesAsync(cancellationToken);
        return decision;
    }

    public static RoutineNotificationDispatchDecision Decide(RecipientQuietHours? setting, DateTime nowUtc)
    {
        if (nowUtc.Kind != DateTimeKind.Utc)
            throw new ArgumentException("UTC time is required.", nameof(nowUtc));
        if (setting is null || !setting.IsEnabled)
            return new RoutineNotificationDispatchDecision(RoutineNotificationDispatchState.SendNow, nowUtc);

        TimeZoneInfo timeZone;
        try
        {
            timeZone = TimeZoneInfo.FindSystemTimeZoneById(setting.TimeZoneId);
        }
        catch (TimeZoneNotFoundException)
        {
            return PendingInvalidTimeZone(nowUtc);
        }
        catch (InvalidTimeZoneException)
        {
            return PendingInvalidTimeZone(nowUtc);
        }

        var localNow = TimeZoneInfo.ConvertTimeFromUtc(nowUtc, timeZone);
        var insideWindow = setting.LocalStart < setting.LocalEnd
            ? localNow.TimeOfDay >= setting.LocalStart.ToTimeSpan() && localNow.TimeOfDay < setting.LocalEnd.ToTimeSpan()
            : localNow.TimeOfDay >= setting.LocalStart.ToTimeSpan() || localNow.TimeOfDay < setting.LocalEnd.ToTimeSpan();
        if (!insideWindow)
            return new RoutineNotificationDispatchDecision(RoutineNotificationDispatchState.SendNow, nowUtc);

        var endDate = localNow.Date;
        if (setting.LocalStart > setting.LocalEnd && localNow.TimeOfDay >= setting.LocalStart.ToTimeSpan())
            endDate = endDate.AddDays(1);
        var localEnd = DateTime.SpecifyKind(endDate.Add(setting.LocalEnd.ToTimeSpan()), DateTimeKind.Unspecified);
        while (timeZone.IsInvalidTime(localEnd))
            localEnd = localEnd.AddMinutes(1);
        return new RoutineNotificationDispatchDecision(
            RoutineNotificationDispatchState.DeferredForQuietHours,
            TimeZoneInfo.ConvertTimeToUtc(localEnd, timeZone));
    }

    private static RoutineNotificationDispatchDecision PendingInvalidTimeZone(DateTime nowUtc) =>
        new(RoutineNotificationDispatchState.PendingInvalidTimeZone, nowUtc.AddMinutes(5));
}

public enum RoutineNotificationDispatchState
{
    SendNow,
    DeferredForQuietHours,
    PendingInvalidTimeZone,
}

public sealed record RoutineNotificationDispatchDecision(RoutineNotificationDispatchState State, DateTime NextAttemptAtUtc);
