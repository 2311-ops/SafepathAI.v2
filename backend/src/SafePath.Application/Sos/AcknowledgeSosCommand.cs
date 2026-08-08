using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

public record AcknowledgeSosCommand(Guid SosSessionId, Guid CallerUserId);

public record AcknowledgeSosResult(SosSessionDto Session);

/// <summary>
/// Acknowledged is strictly stronger than Delivered and is only ever reached through this
/// explicit guardian action (D-22) — never inferred from a successful send or a mere receipt
/// confirmation. Only the caller's own delivery-attempt rows are ever touched; a guardian cannot
/// acknowledge on another recipient's behalf.
/// </summary>
public class AcknowledgeSosCommandHandler : ICommandHandler<AcknowledgeSosCommand, AcknowledgeSosResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IAlertBroadcastService _broadcast;

    public AcknowledgeSosCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IAlertBroadcastService broadcast)
    {
        _db = db;
        _authorization = authorization;
        _broadcast = broadcast;
    }

    public async Task<AcknowledgeSosResult> Handle(AcknowledgeSosCommand command, CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions.SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);
        if (session is null)
        {
            throw new FamilyAuthorizationDeniedException($"SOS session {command.SosSessionId} was not found.");
        }

        await _authorization.RequireMembership(command.CallerUserId, session.FamilyId, cancellationToken);

        var ownAttempts = await _db.SosDeliveryAttempts
            .Where(a => a.SosSessionId == command.SosSessionId && a.RecipientUserId == command.CallerUserId)
            .ToListAsync(cancellationToken);

        var acknowledgedAtUtc = DateTime.UtcNow;
        foreach (var attempt in ownAttempts)
        {
            attempt.Status = SosDeliveryStatus.Acknowledged;
            attempt.AcknowledgedAtUtc = acknowledgedAtUtc;
        }

        if (ownAttempts.Count > 0)
        {
            await _db.SaveChangesAsync(cancellationToken);
        }

        var dto = await SosSessionProjection.ProjectAsync(_db, session, command.CallerUserId, cancellationToken);

        if (ownAttempts.Count > 0)
        {
            // Includes the triggering user, not just the other guardian recipients — the
            // sender's own session must reflect this acknowledgement live (must_haves truth).
            var recipientIds = await SosSessionProjection.ResolveRecipientUserIds(_db, command.SosSessionId, cancellationToken);
            if (!recipientIds.Contains(session.TriggeredByUserId))
            {
                recipientIds.Add(session.TriggeredByUserId);
            }

            foreach (var attempt in ownAttempts)
            {
                await _broadcast.DeliveryStatusChanged(
                    session.FamilyId,
                    recipientIds,
                    new SosDeliveryStatusChangedDto(
                        command.SosSessionId,
                        attempt.RecipientUserId,
                        attempt.EmergencyContactId,
                        attempt.Channel,
                        SosDeliveryStatus.Acknowledged,
                        acknowledgedAtUtc),
                    cancellationToken);
            }
        }

        return new AcknowledgeSosResult(dto);
    }
}
