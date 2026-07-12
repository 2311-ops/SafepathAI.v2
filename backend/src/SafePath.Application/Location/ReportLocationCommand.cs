using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;

namespace SafePath.Application.Location;

public record ReportLocationCommand(
    Guid CallerUserId,
    Guid FamilyId,
    double Latitude,
    double Longitude,
    double AccuracyMeters,
    int? BatteryPercent,
    DateTime RecordedAtUtc);

public record ReportLocationResult(Guid PingId);

public class ReportLocationCommandHandler : ICommandHandler<ReportLocationCommand, ReportLocationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly ILocationBroadcastService _broadcast;

    public ReportLocationCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        ILocationBroadcastService broadcast)
    {
        _db = db;
        _authorization = authorization;
        _broadcast = broadcast;
    }

    public async Task<ReportLocationResult> Handle(ReportLocationCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);
        Validate(command);

        var ping = new LocationPing
        {
            Id = Guid.NewGuid(),
            UserId = command.CallerUserId,
            Latitude = command.Latitude,
            Longitude = command.Longitude,
            AccuracyMeters = command.AccuracyMeters,
            BatteryPercent = command.BatteryPercent,
            RecordedAtUtc = command.RecordedAtUtc,
            ReceivedAtUtc = DateTime.UtcNow,
        };

        _db.LocationPings.Add(ping);
        await _db.SaveChangesAsync(cancellationToken);

        var eligibleRecipients = await _db.FamilyMembers
            .Where(m => m.FamilyId == command.FamilyId && m.IsActive)
            .Select(m => m.UserId)
            .ToListAsync(cancellationToken);

        await _broadcast.BroadcastLocation(
            command.FamilyId,
            new LocationUpdateDto(
                command.CallerUserId,
                command.Latitude,
                command.Longitude,
                command.AccuracyMeters,
                command.BatteryPercent,
                command.RecordedAtUtc),
            eligibleRecipients,
            cancellationToken);

        return new ReportLocationResult(ping.Id);
    }

    private static void Validate(ReportLocationCommand command)
    {
        if (command.Latitude is < -90 or > 90)
        {
            throw new ArgumentException("Latitude must be between -90 and 90.", nameof(command));
        }

        if (command.Longitude is < -180 or > 180)
        {
            throw new ArgumentException("Longitude must be between -180 and 180.", nameof(command));
        }

        if (command.AccuracyMeters < 0)
        {
            throw new ArgumentException("Accuracy must be zero or greater.", nameof(command));
        }

        if (command.BatteryPercent is < 0 or > 100)
        {
            throw new ArgumentException("Battery percent must be between 0 and 100.", nameof(command));
        }

        if (command.RecordedAtUtc > DateTime.UtcNow)
        {
            throw new ArgumentException("RecordedAtUtc cannot be in the future.", nameof(command));
        }
    }
}
