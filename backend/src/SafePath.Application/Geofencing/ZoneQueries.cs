using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

public sealed record ListZonesQuery(Guid CallerUserId, Guid FamilyId);
public sealed record GetZoneQuery(Guid CallerUserId, Guid FamilyId, Guid ZoneId);
public sealed record GetMyZoneRegistrationsQuery(Guid CallerUserId);
public sealed record AcknowledgeCurrentZoneRegistrationCommand(Guid CallerUserId, Guid ZoneId, int Generation);

public sealed record ZoneDto(Guid ZoneId, SafeZoneCategory Category, string? CustomName, double Latitude, double Longitude,
    double RadiusMeters, Guid AssignedMemberUserId, SafeZoneSensitivity Sensitivity, IReadOnlyList<Guid> RecipientUserIds,
    bool NotifyAssignedMember, int RegistrationGeneration, bool Active, bool NeedsLocationPermission, bool NeedsSync);

public sealed class ListZonesQueryHandler : ICommandHandler<ListZonesQuery, IReadOnlyList<ZoneDto>>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    public ListZonesQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization) { _db = db; _authorization = authorization; }
    public async Task<IReadOnlyList<ZoneDto>> Handle(ListZonesQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(query.CallerUserId, query.FamilyId, Role.Guardian, cancellationToken);
        var zones = await _db.SafeZones.Where(zone => zone.FamilyId == query.FamilyId).OrderByDescending(zone => zone.CreatedAtUtc).ToListAsync(cancellationToken);
        return await ZoneProjection.Project(_db, zones, cancellationToken);
    }
}

public sealed class GetZoneQueryHandler : ICommandHandler<GetZoneQuery, ZoneDto?>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    public GetZoneQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization) { _db = db; _authorization = authorization; }
    public async Task<ZoneDto?> Handle(GetZoneQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(query.CallerUserId, query.FamilyId, Role.Guardian, cancellationToken);
        var zone = await _db.SafeZones.SingleOrDefaultAsync(item => item.Id == query.ZoneId && item.FamilyId == query.FamilyId, cancellationToken);
        return zone is null ? null : (await ZoneProjection.Project(_db, [zone], cancellationToken)).Single();
    }
}

public sealed class GetMyZoneRegistrationsQueryHandler : ICommandHandler<GetMyZoneRegistrationsQuery, IReadOnlyList<ZoneDto>>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    public GetMyZoneRegistrationsQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization) { _db = db; _authorization = authorization; }
    public async Task<IReadOnlyList<ZoneDto>> Handle(GetMyZoneRegistrationsQuery query, CancellationToken cancellationToken = default)
    {
        var memberships = await _db.FamilyMembers.Where(member => member.UserId == query.CallerUserId && member.IsActive).Select(member => member.FamilyId).ToListAsync(cancellationToken);
        if (memberships.Count == 0) throw new FamilyAuthorizationDeniedException("Caller has no active family membership.");
        var zones = await _db.SafeZones.Where(zone => zone.IsActive && zone.AssignedMemberUserId == query.CallerUserId && memberships.Contains(zone.FamilyId)).ToListAsync(cancellationToken);
        return await ZoneProjection.Project(_db, zones, cancellationToken);
    }
}

public sealed class AcknowledgeCurrentZoneRegistrationCommandHandler : ICommandHandler<AcknowledgeCurrentZoneRegistrationCommand, bool>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    public AcknowledgeCurrentZoneRegistrationCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization) { _db = db; _authorization = authorization; }
    public async Task<bool> Handle(AcknowledgeCurrentZoneRegistrationCommand command, CancellationToken cancellationToken = default)
    {
        var zone = await _db.SafeZones.SingleOrDefaultAsync(item => item.Id == command.ZoneId && item.IsActive, cancellationToken);
        if (zone is null) return false;
        await _authorization.RequireMembership(command.CallerUserId, zone.FamilyId, cancellationToken);
        if (zone.AssignedMemberUserId != command.CallerUserId) return false;
        var current = await _db.SafeZoneRegistrations.Where(item => item.SafeZoneId == zone.Id).OrderByDescending(item => item.Generation).FirstOrDefaultAsync(cancellationToken);
        if (current is null || current.Generation != command.Generation || current.MemberUserId != command.CallerUserId) return false;
        current.AcknowledgedAtUtc ??= DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}

internal static class ZoneProjection
{
    public static async Task<IReadOnlyList<ZoneDto>> Project(IApplicationDbContext db, IReadOnlyCollection<SafePath.Domain.Entities.SafeZone> zones, CancellationToken cancellationToken)
    {
        var ids = zones.Select(zone => zone.Id).ToArray();
        var recipients = await db.SafeZoneRecipients.Where(item => ids.Contains(item.SafeZoneId)).ToListAsync(cancellationToken);
        var registrations = await db.SafeZoneRegistrations.Where(item => ids.Contains(item.SafeZoneId)).ToListAsync(cancellationToken);
        return zones.Select(zone =>
        {
            var current = registrations.Where(item => item.SafeZoneId == zone.Id).OrderByDescending(item => item.Generation).FirstOrDefault();
            return new ZoneDto(zone.Id, zone.Category, zone.CustomName, zone.Latitude, zone.Longitude, zone.RadiusMeters,
                zone.AssignedMemberUserId, zone.Sensitivity, recipients.Where(item => item.SafeZoneId == zone.Id).Select(item => item.RecipientUserId).ToArray(),
                zone.NotifyAssignedMember, current?.Generation ?? 0, zone.IsActive,
                zone.IsActive && current?.AcknowledgedAtUtc is null, zone.IsActive && current?.AcknowledgedAtUtc is null);
        }).ToArray();
    }
}
