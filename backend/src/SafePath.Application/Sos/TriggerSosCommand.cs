using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

public record TriggerSosCommand(
    Guid SosSessionId,
    Guid CallerUserId,
    Guid FamilyId,
    double? Latitude,
    double? Longitude,
    double? AccuracyMeters,
    DateTime TriggeredAtUtc);

public record TriggerSosResult(SosSessionDto Session, bool WasExistingSession);

/// <summary>
/// Idempotent SOS trigger handler. Deliberately holds no reference to
/// <c>ReportLocationCommandHandler</c>, <c>ILocationBroadcastService</c>,
/// <c>ILowBatteryAlertTracker</c>, or any <c>LocationPing</c> write — SOS-01's isolation
/// guarantee from the routine location pipeline is enforced by that absence.
/// </summary>
public class TriggerSosCommandHandler : ICommandHandler<TriggerSosCommand, TriggerSosResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly ISosAlertDispatcher _dispatcher;
    private readonly IServiceScopeFactory? _scopeFactory;

    public TriggerSosCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        ISosAlertDispatcher dispatcher,
        IServiceScopeFactory? scopeFactory = null)
    {
        _db = db;
        _authorization = authorization;
        _dispatcher = dispatcher;
        _scopeFactory = scopeFactory;
    }

    public async Task<TriggerSosResult> Handle(TriggerSosCommand command, CancellationToken cancellationToken = default)
    {
        var existing = await _db.SosSessions
            .SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);

        if (existing is not null)
        {
            var existingDto = await SosSessionProjection.ProjectAsync(_db, existing, cancellationToken);
            return new TriggerSosResult(existingDto, WasExistingSession: true);
        }

        await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);
        Validate(command);

        var session = new SosSession
        {
            Id = command.SosSessionId,
            FamilyId = command.FamilyId,
            TriggeredByUserId = command.CallerUserId,
            Kind = SosKind.Visible,
            Status = SosSessionStatus.Active,
            Latitude = command.Latitude,
            Longitude = command.Longitude,
            AccuracyMeters = command.AccuracyMeters,
            TriggeredAtUtc = command.TriggeredAtUtc,
            ReceivedAtUtc = DateTime.UtcNow,
        };

        _db.SosSessions.Add(session);

        var recipients = await ResolveRecipients(command.FamilyId, command.CallerUserId, cancellationToken);
        foreach (var recipient in recipients)
        {
            _db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
            {
                Id = Guid.NewGuid(),
                SosSessionId = session.Id,
                RecipientUserId = recipient.UserId,
                Channel = AlertChannel.SignalR,
                Status = SosDeliveryStatus.NotAttempted,
            });
        }

        // D-11 / 03-05: SOS recipients are active Guardians (above) PLUS the sender's own
        // configured emergency contacts (below) — never all active family members. Emergency
        // contacts are SMS-only: no RecipientUserId (they have no app account), no SignalR/FCM
        // row. Deliberately not routed through ISharingAuthorizationService — see the class doc.
        var emergencyContacts = await ResolveEmergencyContacts(command.CallerUserId, cancellationToken);
        foreach (var contact in emergencyContacts)
        {
            _db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
            {
                Id = Guid.NewGuid(),
                SosSessionId = session.Id,
                EmergencyContactId = contact.Id,
                Channel = AlertChannel.Sms,
                Status = SosDeliveryStatus.NotAttempted,
            });
        }

        await _db.SaveChangesAsync(cancellationToken);

        // Fan-out starts only after the commit the idempotency check above depends on, and is
        // never awaited inline — a slow/failing channel must never delay the sender's
        // confirmation (Core Value). It must run against its own DbContext, not this handler's
        // request-scoped `_db`: the HTTP request's DI scope (and `_db` with it) is disposed the
        // moment this method's returned Task completes, which happens before a backgrounded
        // dispatch necessarily finishes, and EF Core's DbContext is not safe for concurrent use
        // by two overlapping operations. A fresh IServiceScopeFactory-created scope keeps the
        // dispatch's own DbContext alive for exactly as long as the dispatch needs it,
        // independent of the request scope's lifetime (same pattern as
        // SharingPreferenceSweepService's background scope usage). Faults are observed via a
        // continuation rather than left as an unobserved task exception; SosAlertDispatcher
        // already isolates per-channel failures internally, so this is a last-resort guard only.
        if (_scopeFactory is not null)
        {
            var scope = _scopeFactory.CreateScope();
            var scopedDispatcher = scope.ServiceProvider.GetRequiredService<ISosAlertDispatcher>();
            var scopedDispatch = scopedDispatcher.DispatchAsync(session.Id, CancellationToken.None);
            _ = scopedDispatch.ContinueWith(
                _ => scope.Dispose(),
                CancellationToken.None,
                TaskContinuationOptions.None,
                TaskScheduler.Default);
        }
        else
        {
            // No scope factory available (e.g. this handler constructed directly, without a DI
            // container, as AlertFanOutTests does) — fall back to the directly-injected
            // dispatcher so unit tests can observe/mock it.
            var dispatch = _dispatcher.DispatchAsync(session.Id, cancellationToken);
            _ = dispatch.ContinueWith(
                static _ => { /* swallow: dispatcher owns per-channel failure handling */ },
                CancellationToken.None,
                TaskContinuationOptions.OnlyOnFaulted,
                TaskScheduler.Default);
        }

        var dto = await SosSessionProjection.ProjectAsync(_db, session, cancellationToken);
        return new TriggerSosResult(dto, WasExistingSession: false);
    }

    /// <summary>
    /// Resolves active Guardians of the caller's family, excluding the caller. This is the
    /// single extension point plan 03-05 widens to also return EmergencyContact rows (D-11).
    /// Deliberately does NOT route through ISharingAuthorizationService — that service gates
    /// routine location visibility and would let a privacy preference suppress an emergency.
    /// </summary>
    private async Task<List<(Guid UserId, string DisplayName)>> ResolveRecipients(
        Guid familyId,
        Guid callerUserId,
        CancellationToken cancellationToken)
    {
        return await _db.FamilyMembers
            .Where(m => m.FamilyId == familyId && m.IsActive && m.Role == Role.Guardian && m.UserId != callerUserId)
            .Join(_db.Users, m => m.UserId, u => u.Id, (m, u) => new { u.Id, u.DisplayName, u.FullName })
            .Select(u => new ValueTuple<Guid, string>(
                u.Id,
                string.IsNullOrWhiteSpace(u.DisplayName) ? u.FullName : u.DisplayName!))
            .ToListAsync(cancellationToken);
    }

    /// <summary>
    /// Resolves the triggering user's own active emergency contacts (03-05, D-11's second
    /// recipient class). Deliberately does NOT route through ISharingAuthorizationService, for
    /// the same reason as <see cref="ResolveRecipients"/> — a routine privacy preference must
    /// never be able to suppress an emergency contact either.
    /// </summary>
    private async Task<List<(Guid Id, string DisplayName)>> ResolveEmergencyContacts(
        Guid callerUserId,
        CancellationToken cancellationToken)
    {
        return await _db.EmergencyContacts
            .Where(c => c.OwnerUserId == callerUserId && c.IsActive)
            .Select(c => new ValueTuple<Guid, string>(c.Id, c.DisplayName))
            .ToListAsync(cancellationToken);
    }

    private static void Validate(TriggerSosCommand command)
    {
        if (command.Latitude is { } latitude && (double.IsNaN(latitude) || latitude is < -90 or > 90))
        {
            throw new ArgumentException("Latitude must be a finite number between -90 and 90.", nameof(command));
        }

        if (command.Longitude is { } longitude && (double.IsNaN(longitude) || longitude is < -180 or > 180))
        {
            throw new ArgumentException("Longitude must be a finite number between -180 and 180.", nameof(command));
        }

        if (command.AccuracyMeters is { } accuracy && (double.IsNaN(accuracy) || accuracy < 0))
        {
            throw new ArgumentException("Accuracy must be a finite number zero or greater.", nameof(command));
        }

        if (command.TriggeredAtUtc > DateTime.UtcNow.AddMinutes(5))
        {
            throw new ArgumentException("TriggeredAtUtc cannot be more than five minutes in the future.", nameof(command));
        }
    }
}
