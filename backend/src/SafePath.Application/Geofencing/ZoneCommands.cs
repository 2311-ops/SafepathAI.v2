using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

public sealed record CreateZoneCommand(Guid CallerUserId, Guid FamilyId, SafeZoneCategory Category, string? CustomName,
    double Latitude, double Longitude, double RadiusMeters, Guid AssignedMemberUserId, SafeZoneSensitivity Sensitivity,
    IReadOnlyCollection<Guid>? RecipientUserIds, bool NotifyAssignedMember);

public sealed record UpdateZoneCommand(Guid CallerUserId, Guid FamilyId, Guid ZoneId, SafeZoneCategory Category, string? CustomName,
    double Latitude, double Longitude, double RadiusMeters, Guid AssignedMemberUserId, SafeZoneSensitivity Sensitivity,
    IReadOnlyCollection<Guid>? RecipientUserIds, bool NotifyAssignedMember);

public sealed record DisableZoneCommand(Guid CallerUserId, Guid FamilyId, Guid ZoneId);
public sealed record DeleteZoneCommand(Guid CallerUserId, Guid FamilyId, Guid ZoneId);

public sealed record ZoneMutationResult(Guid ZoneId, int RegistrationGeneration, bool Active, bool NeedsLocationPermission, bool NeedsSync);

public sealed class CreateZoneCommandHandler : ICommandHandler<CreateZoneCommand, ZoneMutationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public CreateZoneCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<ZoneMutationResult> Handle(CreateZoneCommand command, CancellationToken cancellationToken = default)
    {
        ZoneCommandValidation.Validate(command.Category, command.CustomName, command.Latitude, command.Longitude, command.RadiusMeters, command.Sensitivity);
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        var activeCount = await _db.SafeZones.CountAsync(zone => zone.FamilyId == command.FamilyId && zone.IsActive, cancellationToken);
        if (activeCount >= 20)
        {
            throw new ZoneLimitReachedException();
        }

        await ZoneCommandValidation.ValidateMemberships(_db, command.FamilyId, command.AssignedMemberUserId, command.CallerUserId, command.RecipientUserIds, cancellationToken);
        var recipients = ZoneCommandValidation.ResolveRecipients(command.CallerUserId, command.RecipientUserIds);
        var now = DateTime.UtcNow;
        var zone = new SafeZone
        {
            Id = Guid.NewGuid(), FamilyId = command.FamilyId, AssignedMemberUserId = command.AssignedMemberUserId,
            CreatedByUserId = command.CallerUserId, Category = command.Category, CustomName = ZoneCommandValidation.NormalizeName(command.Category, command.CustomName),
            Latitude = command.Latitude, Longitude = command.Longitude, RadiusMeters = command.RadiusMeters,
            Sensitivity = command.Sensitivity, NotifyAssignedMember = command.NotifyAssignedMember, CreatedAtUtc = now,
        };
        _db.SafeZones.Add(zone);
        foreach (var recipient in recipients)
            _db.SafeZoneRecipients.Add(new SafeZoneRecipient { SafeZoneId = zone.Id, RecipientUserId = recipient });
        _db.SafeZoneRegistrations.Add(ZoneCommandValidation.NewRegistration(zone.Id, command.AssignedMemberUserId, 1, now));
        await _db.SaveChangesAsync(cancellationToken);
        return ZoneCommandValidation.ToMutationResult(zone.Id, 1, active: true, acknowledgedAtUtc: null);
    }
}

public sealed class UpdateZoneCommandHandler : ICommandHandler<UpdateZoneCommand, ZoneMutationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public UpdateZoneCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<ZoneMutationResult> Handle(UpdateZoneCommand command, CancellationToken cancellationToken = default)
    {
        ZoneCommandValidation.Validate(command.Category, command.CustomName, command.Latitude, command.Longitude, command.RadiusMeters, command.Sensitivity);
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);
        var zone = await _db.SafeZones.SingleOrDefaultAsync(item => item.Id == command.ZoneId && item.FamilyId == command.FamilyId && item.IsActive, cancellationToken)
            ?? throw new ZoneNotFoundException();
        await ZoneCommandValidation.ValidateMemberships(_db, command.FamilyId, command.AssignedMemberUserId, command.CallerUserId, command.RecipientUserIds, cancellationToken);

        zone.Category = command.Category;
        zone.CustomName = ZoneCommandValidation.NormalizeName(command.Category, command.CustomName);
        zone.Latitude = command.Latitude;
        zone.Longitude = command.Longitude;
        zone.RadiusMeters = command.RadiusMeters;
        zone.AssignedMemberUserId = command.AssignedMemberUserId;
        zone.Sensitivity = command.Sensitivity;
        zone.NotifyAssignedMember = command.NotifyAssignedMember;
        _db.SafeZoneRecipients.RemoveRange(_db.SafeZoneRecipients.Where(item => item.SafeZoneId == zone.Id));
        foreach (var recipient in ZoneCommandValidation.ResolveRecipients(command.CallerUserId, command.RecipientUserIds))
            _db.SafeZoneRecipients.Add(new SafeZoneRecipient { SafeZoneId = zone.Id, RecipientUserId = recipient });

        var generation = await _db.SafeZoneRegistrations.Where(item => item.SafeZoneId == zone.Id).MaxAsync(item => (int?)item.Generation, cancellationToken) ?? 0;
        generation++;
        _db.SafeZoneRegistrations.Add(ZoneCommandValidation.NewRegistration(zone.Id, command.AssignedMemberUserId, generation, DateTime.UtcNow));
        await _db.SaveChangesAsync(cancellationToken);
        return ZoneCommandValidation.ToMutationResult(zone.Id, generation, active: true, acknowledgedAtUtc: null);
    }
}

public sealed class DisableZoneCommandHandler : ICommandHandler<DisableZoneCommand, ZoneMutationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public DisableZoneCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public Task<ZoneMutationResult> Handle(DisableZoneCommand command, CancellationToken cancellationToken = default) =>
        ZoneCommandValidation.Deactivate(_db, _authorization, command.CallerUserId, command.FamilyId, command.ZoneId, cancellationToken);
}

public sealed class DeleteZoneCommandHandler : ICommandHandler<DeleteZoneCommand, ZoneMutationResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public DeleteZoneCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public Task<ZoneMutationResult> Handle(DeleteZoneCommand command, CancellationToken cancellationToken = default) =>
        ZoneCommandValidation.Deactivate(_db, _authorization, command.CallerUserId, command.FamilyId, command.ZoneId, cancellationToken);
}

public sealed class ZoneLimitReachedException : InvalidOperationException
{
    public ZoneLimitReachedException() : base("A family may have at most 20 active safe zones.") { }
}

public sealed class ZoneNotFoundException : InvalidOperationException
{
    public ZoneNotFoundException() : base("Safe zone was not found.") { }
}

internal static class ZoneCommandValidation
{
    public static void Validate(SafeZoneCategory category, string? customName, double latitude, double longitude, double radiusMeters, SafeZoneSensitivity sensitivity)
    {
        if (!Enum.IsDefined(category) || !Enum.IsDefined(sensitivity) ||
            !double.IsFinite(latitude) || latitude is < -90 or > 90 ||
            !double.IsFinite(longitude) || longitude is < -180 or > 180 ||
            !double.IsFinite(radiusMeters) || radiusMeters is < 100 or > 2000)
            throw new ArgumentException("Zone fields are invalid.");
        if (category == SafeZoneCategory.Custom && string.IsNullOrWhiteSpace(customName))
            throw new ArgumentException("Custom zones require a name.");
    }

    public static string? NormalizeName(SafeZoneCategory category, string? customName) => category == SafeZoneCategory.Custom ? customName?.Trim() : null;

    public static IReadOnlyCollection<Guid> ResolveRecipients(Guid callerUserId, IReadOnlyCollection<Guid>? recipients) =>
        (recipients is null || recipients.Count == 0 ? [callerUserId] : recipients).Distinct().ToArray();

    public static async Task ValidateMemberships(IApplicationDbContext db, Guid familyId, Guid assignedMemberUserId, Guid callerUserId, IReadOnlyCollection<Guid>? recipients, CancellationToken cancellationToken)
    {
        if (assignedMemberUserId == Guid.Empty || !await db.FamilyMembers.AnyAsync(member => member.FamilyId == familyId && member.UserId == assignedMemberUserId && member.IsActive, cancellationToken))
            throw new FamilyAuthorizationDeniedException("Assigned member is not active in this family.");
        var recipientIds = ResolveRecipients(callerUserId, recipients);
        var guardianCount = await db.FamilyMembers.CountAsync(member => member.FamilyId == familyId && member.IsActive && member.Role == Role.Guardian && recipientIds.Contains(member.UserId), cancellationToken);
        if (guardianCount != recipientIds.Count)
            throw new FamilyAuthorizationDeniedException("Every zone recipient must be an active Guardian in the family.");
    }

    public static SafeZoneRegistration NewRegistration(Guid zoneId, Guid memberUserId, int generation, DateTime issuedAtUtc) => new()
    {
        Id = Guid.NewGuid(), SafeZoneId = zoneId, MemberUserId = memberUserId, Generation = generation, IssuedAtUtc = issuedAtUtc,
    };

    public static ZoneMutationResult ToMutationResult(Guid zoneId, int generation, bool active, DateTime? acknowledgedAtUtc) =>
        new(zoneId, generation, active, NeedsLocationPermission: active && acknowledgedAtUtc is null, NeedsSync: active && acknowledgedAtUtc is null);

    public static async Task<ZoneMutationResult> Deactivate(IApplicationDbContext db, IFamilyAuthorizationService authorization, Guid callerUserId, Guid familyId, Guid zoneId, CancellationToken cancellationToken)
    {
        await authorization.RequireRole(callerUserId, familyId, Role.Guardian, cancellationToken);
        var zone = await db.SafeZones.SingleOrDefaultAsync(item => item.Id == zoneId && item.FamilyId == familyId, cancellationToken)
            ?? throw new ZoneNotFoundException();
        var generation = await db.SafeZoneRegistrations.Where(item => item.SafeZoneId == zone.Id).MaxAsync(item => (int?)item.Generation, cancellationToken) ?? 0;
        generation++;
        zone.IsActive = false;
        db.SafeZoneRegistrations.Add(NewRegistration(zone.Id, zone.AssignedMemberUserId, generation, DateTime.UtcNow));
        await db.SaveChangesAsync(cancellationToken);
        return ToMutationResult(zone.Id, generation, active: false, acknowledgedAtUtc: null);
    }
}
