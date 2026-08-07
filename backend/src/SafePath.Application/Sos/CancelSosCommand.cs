using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

public record CancelSosCommand(Guid SosSessionId, Guid CallerUserId);

public record CancelSosResult(SosSessionDto Session);

/// <summary>
/// Self-cancel only (D-05): a guardian, even one who received the alert, can never cancel
/// someone else's emergency — only the user who triggered it can. Cancellation is a parallel
/// follow-up notice that runs alongside the alert, never a retraction of it — this handler never
/// deletes, downgrades, or marks Failed any <see cref="Domain.Entities.SosDeliveryAttempt"/> row
/// (D-24), and never touches the trigger path.
/// </summary>
public class CancelSosCommandHandler : ICommandHandler<CancelSosCommand, CancelSosResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IAlertBroadcastService _broadcast;

    public CancelSosCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IAlertBroadcastService broadcast)
    {
        _db = db;
        _authorization = authorization;
        _broadcast = broadcast;
    }

    public async Task<CancelSosResult> Handle(CancelSosCommand command, CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);
        if (session is null)
        {
            throw new FamilyAuthorizationDeniedException($"SOS session {command.SosSessionId} was not found.");
        }

        await _authorization.RequireMembership(command.CallerUserId, session.FamilyId, cancellationToken);

        if (session.TriggeredByUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException(
                "Only the user who triggered an SOS session may cancel it.");
        }

        if (session.Status == SosSessionStatus.Canceled)
        {
            // Idempotent: leaves the first cancellation's timestamp untouched and does not
            // broadcast again.
            var unchangedDto = await SosSessionProjection.ProjectAsync(_db, session, command.CallerUserId, cancellationToken);
            return new CancelSosResult(unchangedDto);
        }

        session.Status = SosSessionStatus.Canceled;
        session.CanceledAtUtc = DateTime.UtcNow;
        session.CanceledByUserId = command.CallerUserId;
        await _db.SaveChangesAsync(cancellationToken);

        var dto = await SosSessionProjection.ProjectAsync(_db, session, command.CallerUserId, cancellationToken);

        var callerDisplayName = await _db.Users
            .Where(u => u.Id == command.CallerUserId)
            .Select(u => string.IsNullOrWhiteSpace(u.DisplayName) ? u.FullName : u.DisplayName!)
            .SingleOrDefaultAsync(cancellationToken) ?? "Unknown";

        // Same recipient set the trigger resolved — the guardians who received the original
        // alert are told about the cancellation through the same channel, never a retraction.
        var recipientIds = await SosSessionProjection.ResolveRecipientUserIds(_db, command.SosSessionId, cancellationToken);
        await _broadcast.SosCanceled(
            session.FamilyId,
            recipientIds,
            new SosCanceledDto(command.SosSessionId, command.CallerUserId, callerDisplayName, session.CanceledAtUtc.Value),
            cancellationToken);

        return new CancelSosResult(dto);
    }
}
