using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;

namespace SafePath.Application.Geofencing;

public sealed record QuietHoursDto(bool IsEnabled, TimeOnly LocalStart, TimeOnly LocalEnd, string TimeZoneId);

public sealed record GetQuietHoursQuery(Guid RecipientUserId);

public sealed class GetQuietHoursQueryHandler : ICommandHandler<GetQuietHoursQuery, QuietHoursDto>
{
    private readonly IApplicationDbContext _db;

    public GetQuietHoursQueryHandler(IApplicationDbContext db) => _db = db;

    public async Task<QuietHoursDto> Handle(GetQuietHoursQuery query, CancellationToken cancellationToken = default)
    {
        if (query.RecipientUserId == Guid.Empty)
            throw new ArgumentException("Recipient is required.", nameof(query));

        var setting = await _db.RecipientQuietHours.AsNoTracking().SingleOrDefaultAsync(
            item => item.RecipientUserId == query.RecipientUserId,
            cancellationToken);
        return setting is null
            ? new QuietHoursDto(false, TimeOnly.MinValue, TimeOnly.MinValue, "Etc/UTC")
            : new QuietHoursDto(setting.IsEnabled, setting.LocalStart, setting.LocalEnd, setting.TimeZoneId);
    }
}

public sealed record UpdateQuietHoursCommand(
    Guid RecipientUserId,
    bool IsEnabled,
    TimeOnly LocalStart,
    TimeOnly LocalEnd,
    string TimeZoneId);

public sealed class UpdateQuietHoursCommandHandler : ICommandHandler<UpdateQuietHoursCommand, QuietHoursDto>
{
    private readonly IApplicationDbContext _db;

    public UpdateQuietHoursCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<QuietHoursDto> Handle(UpdateQuietHoursCommand command, CancellationToken cancellationToken = default)
    {
        if (command.RecipientUserId == Guid.Empty || command.LocalStart == command.LocalEnd || !IsIanaZone(command.TimeZoneId))
            throw new ArgumentException("Quiet-hours settings are invalid.", nameof(command));

        var setting = await _db.RecipientQuietHours.SingleOrDefaultAsync(
            item => item.RecipientUserId == command.RecipientUserId,
            cancellationToken);
        if (setting is null)
        {
            setting = new RecipientQuietHours { Id = Guid.NewGuid(), RecipientUserId = command.RecipientUserId };
            _db.RecipientQuietHours.Add(setting);
        }

        setting.IsEnabled = command.IsEnabled;
        setting.LocalStart = command.LocalStart;
        setting.LocalEnd = command.LocalEnd;
        setting.TimeZoneId = command.TimeZoneId.Trim();
        setting.UpdatedAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return new QuietHoursDto(setting.IsEnabled, setting.LocalStart, setting.LocalEnd, setting.TimeZoneId);
    }

    internal static bool IsIanaZone(string? timeZoneId)
    {
        var candidate = timeZoneId?.Trim();
        if (string.IsNullOrWhiteSpace(candidate) || (candidate != "UTC" && !candidate.Contains('/')))
            return false;
        try
        {
            _ = TimeZoneInfo.FindSystemTimeZoneById(candidate);
            return true;
        }
        catch (TimeZoneNotFoundException) { return false; }
        catch (InvalidTimeZoneException) { return false; }
    }
}
