using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

public record ReportSosLocationCommand(
    Guid SosSessionId,
    Guid CallerUserId,
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    DateTime RecordedAtUtc);

public enum ReportSosLocationOutcome
{
    Accepted,
    SessionNotFound,
    WindowClosed,
}

/// <summary>
/// <see cref="LiveWindowEndsAtUtc"/> is always echoed back (when known) so the client can
/// self-terminate its foreground service the moment the server says the window has closed,
/// rather than trusting its own local clock (D-21).
/// </summary>
public record ReportSosLocationResult(ReportSosLocationOutcome Outcome, DateTime? LiveWindowEndsAtUtc);

/// <summary>
/// Window-gated live position ingest for an active SOS (SOS-04, D-21, D-31). Structurally
/// separate from the routine location pipeline in both directions (T-03-09/SOS-01 isolation):
/// this handler never persists a LocationPing row and never calls
/// ReportLocationCommandHandler, ILocationBroadcastService, ISharingAuthorizationService, or
/// ILowBatteryAlertTracker. A routine privacy sharing preference must never be able to blank a
/// responder's view during an active emergency (T-03-30, accepted disposition).
/// </summary>
public class ReportSosLocationCommandHandler : ICommandHandler<ReportSosLocationCommand, ReportSosLocationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IAlertBroadcastService _broadcast;

    public ReportSosLocationCommandHandler(IApplicationDbContext db, IAlertBroadcastService broadcast)
    {
        _db = db;
        _broadcast = broadcast;
    }

    public async Task<ReportSosLocationResult> Handle(ReportSosLocationCommand command, CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);
        if (session is null)
        {
            return new ReportSosLocationResult(ReportSosLocationOutcome.SessionNotFound, null);
        }

        // Only the person in danger streams their own position — never a guardian, and never
        // anyone else's session (T-03-27).
        if (session.TriggeredByUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException(
                "Only the user who triggered an SOS session may stream their position into it.");
        }

        // The stream stops on schedule regardless of a client that keeps sending: a canceled
        // session or an expired window is a normal refusal the client should act on (stop the
        // foreground service), not an exceptional error.
        if (session.Status == SosSessionStatus.Canceled
            || session.LiveWindowEndsAtUtc is null
            || DateTime.UtcNow > session.LiveWindowEndsAtUtc)
        {
            return new ReportSosLocationResult(ReportSosLocationOutcome.WindowClosed, session.LiveWindowEndsAtUtc);
        }

        Validate(command);

        var recipientIds = await SosSessionProjection.ResolveRecipientUserIds(_db, session.Id, cancellationToken);
        await _broadcast.LiveLocationWindowUpdate(
            session.FamilyId,
            recipientIds,
            new SosLocationUpdateDto(
                session.Id,
                command.Latitude,
                command.Longitude,
                command.AccuracyMeters,
                command.RecordedAtUtc,
                session.LiveWindowEndsAtUtc.Value),
            cancellationToken);

        return new ReportSosLocationResult(ReportSosLocationOutcome.Accepted, session.LiveWindowEndsAtUtc);
    }

    private static void Validate(ReportSosLocationCommand command)
    {
        if (double.IsNaN(command.Latitude) || command.Latitude is < -90 or > 90)
        {
            throw new ArgumentException("Latitude must be a finite number between -90 and 90.", nameof(command));
        }

        if (double.IsNaN(command.Longitude) || command.Longitude is < -180 or > 180)
        {
            throw new ArgumentException("Longitude must be a finite number between -180 and 180.", nameof(command));
        }

        if (command.AccuracyMeters is { } accuracy && (double.IsNaN(accuracy) || accuracy < 0))
        {
            throw new ArgumentException("Accuracy must be a finite number zero or greater.", nameof(command));
        }
    }
}
