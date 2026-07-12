using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Privacy;

public record ExportMyDataQuery(Guid CallerUserId);

public class ExportMyDataQueryHandler : ICommandHandler<ExportMyDataQuery, MyDataExportDto>
{
    private readonly IApplicationDbContext _db;

    public ExportMyDataQueryHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<MyDataExportDto> Handle(ExportMyDataQuery query, CancellationToken cancellationToken = default)
    {
        var locationPings = await _db.LocationPings
            .Where(p => p.UserId == query.CallerUserId)
            .OrderBy(p => p.RecordedAtUtc)
            .Select(p => new ExportLocationPingDto(
                p.Id,
                p.UserId,
                p.Latitude,
                p.Longitude,
                p.AccuracyMeters,
                p.BatteryPercent,
                p.RecordedAtUtc,
                p.ReceivedAtUtc))
            .ToListAsync(cancellationToken);

        var sharingPreferences = await _db.SharingPreferences
            .Where(p => p.OwnerUserId == query.CallerUserId)
            .OrderBy(p => p.DataType)
            .ThenBy(p => p.RecipientMemberId)
            .Select(p => new ExportSharingPreferenceDto(
                p.Id,
                p.FamilyId,
                p.OwnerUserId,
                p.RecipientMemberId,
                p.DataType,
                p.IsEnabled,
                p.ExpiresAtUtc))
            .ToListAsync(cancellationToken);

        return new MyDataExportDto(locationPings, sharingPreferences);
    }
}
