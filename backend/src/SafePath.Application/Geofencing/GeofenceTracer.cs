using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

public sealed record CreateSafeZoneCommand(
    Guid CallerUserId,
    Guid FamilyId,
    SafeZoneCategory Category,
    string? CustomName,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    Guid AssignedMemberUserId,
    SafeZoneSensitivity Sensitivity,
    IReadOnlyCollection<Guid> RecipientUserIds,
    bool NotifyAssignedMember);

public sealed record SafeZoneRegistrationDto(
    Guid ZoneId,
    int Generation,
    SafeZoneCategory Category,
    string? CustomName,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    SafeZoneSensitivity Sensitivity,
    bool NotifyAssignedMember,
    DateTime? AcknowledgedAtUtc);

public sealed record CreateSafeZoneResult(Guid ZoneId, int RegistrationGeneration);
public sealed record GetMySafeZoneRegistrationQuery(Guid CallerUserId);
public sealed record AcknowledgeSafeZoneRegistrationCommand(Guid CallerUserId, Guid ZoneId, int Generation);
public sealed record SubmitGeofenceCandidateCommand(
    Guid CallerUserId,
    Guid EventId,
    Guid ZoneId,
    int RegistrationGeneration,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    double Latitude,
    double Longitude,
    double AccuracyMeters);

public enum GeofenceCandidateOutcome { Accepted, Duplicate }
public sealed record SubmitGeofenceCandidateResult(GeofenceCandidateOutcome Outcome);

public sealed class CreateSafeZoneCommandHandler : ICommandHandler<CreateSafeZoneCommand, CreateSafeZoneResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public CreateSafeZoneCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<CreateSafeZoneResult> Handle(CreateSafeZoneCommand command, CancellationToken cancellationToken = default)
    {
        Validate(command);
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        var assignedMemberIsActive = await _db.FamilyMembers.AnyAsync(
            member => member.FamilyId == command.FamilyId && member.UserId == command.AssignedMemberUserId && member.IsActive,
            cancellationToken);
        if (!assignedMemberIsActive)
        {
            throw new FamilyAuthorizationDeniedException("Assigned member is not active in this family.");
        }

        var recipientIds = command.RecipientUserIds.Distinct().ToArray();
        var activeGuardianCount = await _db.FamilyMembers.CountAsync(
            member => member.FamilyId == command.FamilyId && member.IsActive && member.Role == Role.Guardian && recipientIds.Contains(member.UserId),
            cancellationToken);
        if (activeGuardianCount != recipientIds.Length)
        {
            throw new FamilyAuthorizationDeniedException("Every zone recipient must be an active Guardian in the family.");
        }

        var zone = new SafeZone
        {
            Id = Guid.NewGuid(),
            FamilyId = command.FamilyId,
            AssignedMemberUserId = command.AssignedMemberUserId,
            CreatedByUserId = command.CallerUserId,
            Category = command.Category,
            CustomName = command.CustomName?.Trim(),
            Latitude = command.Latitude,
            Longitude = command.Longitude,
            RadiusMeters = command.RadiusMeters,
            Sensitivity = command.Sensitivity,
            NotifyAssignedMember = command.NotifyAssignedMember,
            CreatedAtUtc = DateTime.UtcNow,
        };
        _db.SafeZones.Add(zone);
        foreach (var recipientUserId in recipientIds)
        {
            _db.SafeZoneRecipients.Add(new SafeZoneRecipient { SafeZoneId = zone.Id, RecipientUserId = recipientUserId });
        }

        _db.SafeZoneRegistrations.Add(new SafeZoneRegistration
        {
            Id = Guid.NewGuid(),
            SafeZoneId = zone.Id,
            MemberUserId = command.AssignedMemberUserId,
            Generation = 1,
            IssuedAtUtc = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync(cancellationToken);
        return new CreateSafeZoneResult(zone.Id, 1);
    }

    private static void Validate(CreateSafeZoneCommand command)
    {
        if (!double.IsFinite(command.Latitude) || command.Latitude is < -90 or > 90 ||
            !double.IsFinite(command.Longitude) || command.Longitude is < -180 or > 180 ||
            !double.IsFinite(command.RadiusMeters) || command.RadiusMeters <= 0)
        {
            throw new ArgumentException("Zone coordinates and radius must be finite and within valid bounds.", nameof(command));
        }

        if (command.Category == SafeZoneCategory.Custom && string.IsNullOrWhiteSpace(command.CustomName))
        {
            throw new ArgumentException("Custom zones require a name.", nameof(command));
        }
    }
}

public sealed class GetMySafeZoneRegistrationQueryHandler : ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public GetMySafeZoneRegistrationQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<SafeZoneRegistrationDto?> Handle(GetMySafeZoneRegistrationQuery query, CancellationToken cancellationToken = default)
    {
        var registration = await _db.SafeZoneRegistrations
            .Join(_db.SafeZones, registration => registration.SafeZoneId, zone => zone.Id, (registration, zone) => new { registration, zone })
            .Where(item => item.registration.MemberUserId == query.CallerUserId && item.zone.IsActive)
            .OrderByDescending(item => item.registration.IssuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (registration is null)
        {
            var hasAnyActiveMembership = await _db.FamilyMembers.AnyAsync(member => member.UserId == query.CallerUserId && member.IsActive, cancellationToken);
            if (!hasAnyActiveMembership)
            {
                throw new FamilyAuthorizationDeniedException("Caller has no active family membership.");
            }
            return null;
        }

        await _authorization.RequireMembership(query.CallerUserId, registration.zone.FamilyId, cancellationToken);
        return new SafeZoneRegistrationDto(
            registration.zone.Id,
            registration.registration.Generation,
            registration.zone.Category,
            registration.zone.CustomName,
            registration.zone.Latitude,
            registration.zone.Longitude,
            registration.zone.RadiusMeters,
            registration.zone.Sensitivity,
            registration.zone.NotifyAssignedMember,
            registration.registration.AcknowledgedAtUtc);
    }
}

public sealed class AcknowledgeSafeZoneRegistrationCommandHandler : ICommandHandler<AcknowledgeSafeZoneRegistrationCommand, bool>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public AcknowledgeSafeZoneRegistrationCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<bool> Handle(AcknowledgeSafeZoneRegistrationCommand command, CancellationToken cancellationToken = default)
    {
        var zone = await _db.SafeZones.SingleOrDefaultAsync(zone => zone.Id == command.ZoneId && zone.IsActive, cancellationToken);
        if (zone is null)
        {
            return false;
        }
        await _authorization.RequireMembership(command.CallerUserId, zone.FamilyId, cancellationToken);
        var registration = await _db.SafeZoneRegistrations.SingleOrDefaultAsync(
            item => item.SafeZoneId == command.ZoneId && item.Generation == command.Generation && item.MemberUserId == command.CallerUserId,
            cancellationToken);
        if (registration is null)
        {
            return false;
        }

        registration.AcknowledgedAtUtc ??= DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}

public sealed class SubmitGeofenceCandidateCommandHandler : ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public SubmitGeofenceCandidateCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<SubmitGeofenceCandidateResult> Handle(SubmitGeofenceCandidateCommand command, CancellationToken cancellationToken = default)
    {
        Validate(command);
        var zone = await _db.SafeZones.SingleOrDefaultAsync(zone => zone.Id == command.ZoneId && zone.IsActive, cancellationToken);
        if (zone is null)
        {
            throw new ArgumentException("Unknown or inactive zone.", nameof(command));
        }
        await _authorization.RequireMembership(command.CallerUserId, zone.FamilyId, cancellationToken);
        if (zone.AssignedMemberUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException("Only the assigned member may submit a zone candidate.");
        }

        var currentGeneration = await _db.SafeZoneRegistrations
            .Where(registration => registration.SafeZoneId == command.ZoneId && registration.MemberUserId == command.CallerUserId)
            .MaxAsync(registration => (int?)registration.Generation, cancellationToken);
        var registrationMatches = currentGeneration == command.RegistrationGeneration;
        if (!registrationMatches)
        {
            throw new ArgumentException("Unknown registration generation.", nameof(command));
        }

        var existing = await _db.GeofenceCandidates.SingleOrDefaultAsync(candidate => candidate.EventId == command.EventId, cancellationToken);
        if (existing is not null)
        {
            if (existing.SafeZoneId == command.ZoneId && existing.MemberUserId == command.CallerUserId)
            {
                return new SubmitGeofenceCandidateResult(GeofenceCandidateOutcome.Duplicate);
            }
            throw new ArgumentException("Event id is already bound to another candidate.", nameof(command));
        }

        _db.GeofenceCandidates.Add(new GeofenceCandidate
        {
            Id = Guid.NewGuid(),
            EventId = command.EventId,
            SafeZoneId = command.ZoneId,
            MemberUserId = command.CallerUserId,
            RegistrationGeneration = command.RegistrationGeneration,
            Transition = command.Transition,
            OccurredAtUtc = command.OccurredAtUtc,
            Latitude = command.Latitude,
            Longitude = command.Longitude,
            AccuracyMeters = command.AccuracyMeters,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        try
        {
            await _db.SaveChangesAsync(cancellationToken);
            return new SubmitGeofenceCandidateResult(GeofenceCandidateOutcome.Accepted);
        }
        catch (DbUpdateException)
        {
            // The database unique constraint is the race-safe idempotency backstop. A second
            // concurrent upload of this caller's own event is still a normal duplicate.
            var persisted = await _db.GeofenceCandidates.AsNoTracking().SingleOrDefaultAsync(candidate => candidate.EventId == command.EventId, cancellationToken);
            if (persisted is not null && persisted.SafeZoneId == command.ZoneId && persisted.MemberUserId == command.CallerUserId)
            {
                return new SubmitGeofenceCandidateResult(GeofenceCandidateOutcome.Duplicate);
            }
            throw;
        }
    }

    private static void Validate(SubmitGeofenceCandidateCommand command)
    {
        if (command.EventId == Guid.Empty || command.ZoneId == Guid.Empty || command.RegistrationGeneration <= 0 ||
            !double.IsFinite(command.Latitude) || command.Latitude is < -90 or > 90 ||
            !double.IsFinite(command.Longitude) || command.Longitude is < -180 or > 180 ||
            !double.IsFinite(command.AccuracyMeters) || command.AccuracyMeters < 0 ||
            command.OccurredAtUtc > DateTime.UtcNow.AddMinutes(5))
        {
            throw new ArgumentException("Candidate fields are invalid.", nameof(command));
        }
    }
}
