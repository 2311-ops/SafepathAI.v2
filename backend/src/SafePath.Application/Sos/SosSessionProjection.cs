using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;

namespace SafePath.Application.Sos;

/// <summary>
/// Shared session -> DTO projection used by both <see cref="TriggerSosCommandHandler"/> and
/// <see cref="GetSosSessionQueryHandler"/>, so the per-recipient/per-channel shaping logic
/// exists in exactly one place.
/// </summary>
internal static class SosSessionProjection
{
    public static async Task<SosSessionDto> ProjectAsync(
        IApplicationDbContext db,
        SosSession session,
        CancellationToken cancellationToken)
    {
        var attempts = await db.SosDeliveryAttempts
            .Where(a => a.SosSessionId == session.Id)
            .ToListAsync(cancellationToken);

        var recipientIds = attempts
            .Where(a => a.RecipientUserId.HasValue)
            .Select(a => a.RecipientUserId!.Value)
            .Distinct()
            .ToList();
        var contactIds = attempts
            .Where(a => a.EmergencyContactId.HasValue)
            .Select(a => a.EmergencyContactId!.Value)
            .Distinct()
            .ToList();

        var userNames = recipientIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await db.Users
                .Where(u => recipientIds.Contains(u.Id))
                .Select(u => new { u.Id, u.DisplayName, u.FullName })
                .ToDictionaryAsync(
                    u => u.Id,
                    u => string.IsNullOrWhiteSpace(u.DisplayName) ? u.FullName : u.DisplayName!,
                    cancellationToken);

        var contactNames = contactIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await db.EmergencyContacts
                .Where(c => contactIds.Contains(c.Id))
                .ToDictionaryAsync(c => c.Id, c => c.DisplayName, cancellationToken);

        var recipients = attempts
            .GroupBy(a => (a.RecipientUserId, a.EmergencyContactId))
            .Select(g =>
            {
                var displayName = g.Key.RecipientUserId is { } uid && userNames.TryGetValue(uid, out var uName)
                    ? uName
                    : g.Key.EmergencyContactId is { } cid && contactNames.TryGetValue(cid, out var cName)
                        ? cName
                        : "Unknown";

                var channels = g
                    .Select(a => new SosChannelStatusDto(a.Channel, a.Status, a.QueuedAtUtc, a.DeliveredAtUtc, a.AcknowledgedAtUtc))
                    .ToList();

                return new SosRecipientStatusDto(g.Key.RecipientUserId, g.Key.EmergencyContactId, displayName, channels);
            })
            .ToList();

        return new SosSessionDto(
            session.Id,
            session.FamilyId,
            session.TriggeredByUserId,
            session.Kind,
            session.Status,
            session.TriggeredAtUtc,
            session.ReceivedAtUtc,
            session.LiveWindowEndsAtUtc,
            session.CanceledAtUtc,
            recipients);
    }

    /// <summary>
    /// Distinct guardian recipient user ids resolved from this session's delivery attempts —
    /// the same set <see cref="TriggerSosCommandHandler"/> used to fan out the original
    /// SosTriggered event. Does not include the triggering user; callers that need the sender
    /// to also receive a live update (e.g. AcknowledgeSosCommandHandler) add it explicitly.
    /// </summary>
    public static async Task<List<Guid>> ResolveRecipientUserIds(
        IApplicationDbContext db,
        Guid sosSessionId,
        CancellationToken cancellationToken) =>
        await db.SosDeliveryAttempts
            .Where(a => a.SosSessionId == sosSessionId && a.RecipientUserId != null)
            .Select(a => a.RecipientUserId!.Value)
            .Distinct()
            .ToListAsync(cancellationToken);
}
