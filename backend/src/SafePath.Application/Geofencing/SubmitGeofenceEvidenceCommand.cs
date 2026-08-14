using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Geofencing;

public sealed record SubmitGeofenceEvidenceCommand(
    Guid CallerUserId,
    Guid EventId,
    Guid ZoneId,
    int RegistrationGeneration,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    double Latitude,
    double Longitude,
    double AccuracyMeters);

public sealed class SubmitGeofenceEvidenceCommandHandler : ICommandHandler<SubmitGeofenceEvidenceCommand, SubmitGeofenceEvidenceResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public SubmitGeofenceEvidenceCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<SubmitGeofenceEvidenceResult> Handle(SubmitGeofenceEvidenceCommand command, CancellationToken cancellationToken = default)
    {
        Validate(command);
        var zone = await _db.SafeZones.SingleOrDefaultAsync(item => item.Id == command.ZoneId && item.IsActive, cancellationToken)
            ?? throw new ArgumentException("Unknown or inactive zone.", nameof(command));
        await _authorization.RequireMembership(command.CallerUserId, zone.FamilyId, cancellationToken);
        if (zone.AssignedMemberUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException("Only the assigned member may submit zone evidence.");
        }

        var currentGeneration = await _db.SafeZoneRegistrations
            .Where(item => item.SafeZoneId == zone.Id && item.MemberUserId == command.CallerUserId)
            .MaxAsync(item => (int?)item.Generation, cancellationToken);
        if (currentGeneration != command.RegistrationGeneration)
        {
            throw new ArgumentException("Unknown registration generation.", nameof(command));
        }

        var existing = await _db.GeofenceCandidates.SingleOrDefaultAsync(item => item.EventId == command.EventId, cancellationToken);
        if (existing is not null)
        {
            if (existing.SafeZoneId == zone.Id && existing.MemberUserId == command.CallerUserId)
            {
                return new SubmitGeofenceEvidenceResult(GeofenceEvidenceOutcome.Duplicate);
            }
            throw new ArgumentException("Event id is already bound to another candidate.", nameof(command));
        }

        var confirmation = await _db.GeofenceConfirmationCandidates.SingleOrDefaultAsync(item =>
            item.SafeZoneId == zone.Id && item.MemberUserId == command.CallerUserId &&
            item.RegistrationGeneration == command.RegistrationGeneration && item.IntendedTransition == command.Transition,
            cancellationToken);
        var currentState = confirmation is { State: GeofenceConfirmationCandidateState.Pending }
            ? new GeofenceTransitionState(confirmation.IntendedTransition, confirmation.FirstObservedAtUtc, confirmation.LastObservedAtUtc)
            : GeofenceTransitionState.Empty;
        var nowUtc = DateTime.UtcNow;
        var evaluation = GeofenceTransitionEvaluator.Evaluate(
            new GeofenceTransitionEvidence(command.Transition, command.OccurredAtUtc, command.Latitude, command.Longitude, command.AccuracyMeters),
            new GeofenceZoneGeometry(zone.Latitude, zone.Longitude, zone.RadiusMeters, zone.Sensitivity), currentState, nowUtc);

        _db.GeofenceCandidates.Add(new GeofenceCandidate
        {
            Id = Guid.NewGuid(), EventId = command.EventId, SafeZoneId = zone.Id, MemberUserId = command.CallerUserId,
            RegistrationGeneration = command.RegistrationGeneration, Transition = command.Transition, OccurredAtUtc = command.OccurredAtUtc,
            Latitude = command.Latitude, Longitude = command.Longitude, AccuracyMeters = command.AccuracyMeters, ReceivedAtUtc = nowUtc,
        });

        if (evaluation.Outcome == GeofenceEvaluationOutcome.Confirmed)
        {
            await AddDurableConfirmationAsync(zone, command, nowUtc, cancellationToken);
        }

        if (confirmation is null)
        {
            confirmation = new GeofenceConfirmationCandidate { Id = Guid.NewGuid(), SafeZoneId = zone.Id, MemberUserId = command.CallerUserId, RegistrationGeneration = command.RegistrationGeneration, IntendedTransition = command.Transition };
            _db.GeofenceConfirmationCandidates.Add(confirmation);
        }
        confirmation.State = evaluation.Outcome switch
        {
            GeofenceEvaluationOutcome.Confirmed => GeofenceConfirmationCandidateState.Confirmed,
            GeofenceEvaluationOutcome.Waiting when evaluation.State.FirstClearSideObservedAtUtc is not null => GeofenceConfirmationCandidateState.Pending,
            _ => GeofenceConfirmationCandidateState.Reset,
        };
        confirmation.FirstObservedAtUtc = evaluation.State.FirstClearSideObservedAtUtc ?? command.OccurredAtUtc;
        confirmation.LastObservedAtUtc = evaluation.State.LastObservedAtUtc ?? command.OccurredAtUtc;
        confirmation.UpdatedAtUtc = nowUtc;

        try
        {
            await _db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            var persisted = await _db.GeofenceCandidates.AsNoTracking().SingleOrDefaultAsync(item => item.EventId == command.EventId, cancellationToken);
            if (persisted is not null && persisted.SafeZoneId == zone.Id && persisted.MemberUserId == command.CallerUserId)
            {
                return new SubmitGeofenceEvidenceResult(GeofenceEvidenceOutcome.Duplicate);
            }
            throw;
        }

        return new SubmitGeofenceEvidenceResult(evaluation.Outcome switch
        {
            GeofenceEvaluationOutcome.Confirmed => GeofenceEvidenceOutcome.Confirmed,
            GeofenceEvaluationOutcome.Reset => GeofenceEvidenceOutcome.Reset,
            _ => GeofenceEvidenceOutcome.Waiting,
        });
    }

    private async Task AddDurableConfirmationAsync(SafeZone zone, SubmitGeofenceEvidenceCommand command, DateTime nowUtc, CancellationToken cancellationToken)
    {
        var recipientIds = await _db.SafeZoneRecipients
            .Where(item => item.SafeZoneId == zone.Id)
            .Join(_db.FamilyMembers, item => item.RecipientUserId, member => member.UserId, (item, member) => new { item, member })
            .Where(item => item.member.FamilyId == zone.FamilyId && item.member.IsActive && item.member.Role == Role.Guardian)
            .Select(item => item.item.RecipientUserId)
            .ToListAsync(cancellationToken);
        if (zone.NotifyAssignedMember)
        {
            recipientIds.Add(command.CallerUserId);
        }

        var activity = new GeofenceActivity
        {
            Id = Guid.NewGuid(), SafeZoneId = zone.Id, SafeZoneDisplayName = zone.CustomName ?? zone.Category.ToString(),
            MemberUserId = command.CallerUserId, Transition = command.Transition, OccurredAtUtc = command.OccurredAtUtc,
            RecordedAtUtc = nowUtc, RetainUntilUtc = nowUtc.AddDays(7),
        };
        _db.GeofenceActivities.Add(activity);
        foreach (var recipientUserId in recipientIds.Distinct())
        {
            var feed = new GeofenceFeedItem { Id = Guid.NewGuid(), ActivityId = activity.Id, RecipientUserId = recipientUserId, CreatedAtUtc = nowUtc, ExpiresAtUtc = nowUtc.AddDays(7) };
            _db.GeofenceFeedItems.Add(feed);
            _db.GeofenceRoutineJobs.Add(new GeofenceRoutineJob { Id = Guid.NewGuid(), FeedItemId = feed.Id, RecipientUserId = recipientUserId, State = GeofenceRoutineJobState.Pending, NextAttemptAtUtc = nowUtc, CreatedAtUtc = nowUtc, ExpiresAtUtc = nowUtc.AddDays(7) });
        }
    }

    private static void Validate(SubmitGeofenceEvidenceCommand command)
    {
        if (command.CallerUserId == Guid.Empty || command.EventId == Guid.Empty || command.ZoneId == Guid.Empty || command.RegistrationGeneration <= 0 ||
            command.OccurredAtUtc.Kind != DateTimeKind.Utc || command.OccurredAtUtc > DateTime.UtcNow.AddMinutes(5) ||
            !double.IsFinite(command.Latitude) || command.Latitude is < -90 or > 90 ||
            !double.IsFinite(command.Longitude) || command.Longitude is < -180 or > 180 ||
            !double.IsFinite(command.AccuracyMeters) || command.AccuracyMeters < 0)
        {
            throw new ArgumentException("Evidence fields are invalid.", nameof(command));
        }
    }
}
