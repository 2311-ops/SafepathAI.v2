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
    /// <summary>
    /// The standard entry point. <paramref name="callerUserId"/> is REQUIRED — no default
    /// value — so the compiler forces every call site to state whose eyes this payload is
    /// for; a defaulted parameter would let a future handler silently inherit blanket
    /// visibility of the sender's phone number (T-RK2-01). Visibility is
    /// <c>recipientIds.Contains(callerUserId)</c> against this session's own
    /// delivery-attempt rows: because <see cref="TriggerSosCommandHandler"/> structurally
    /// excludes the triggering user from that set, the sender never seeing their own number
    /// falls out of this one expression with no special case, and a family member who merely
    /// passed <c>RequireMembership</c> without an actual delivery-attempt row is excluded by
    /// the same expression.
    /// </summary>
    public static async Task<SosSessionDto> ProjectAsync(
        IApplicationDbContext db,
        SosSession session,
        Guid callerUserId,
        CancellationToken cancellationToken)
    {
        var recipientIds = await ResolveRecipientUserIds(db, session.Id, cancellationToken);
        return await ProjectCoreAsync(db, session, phoneNumberVisible: recipientIds.Contains(callerUserId), cancellationToken);
    }

    /// <summary>
    /// The ONLY legal caller of this entry point is a fan-out whose delivery audience is
    /// exactly this session's distinct delivery-attempt recipient set —
    /// <see cref="SosAlertDispatcher.DispatchSignalR"/>, and nowhere else. Any other use is a
    /// leak (T-RK2-02): unlike <see cref="ProjectAsync"/>, there is no single caller id here,
    /// so visibility is unconditionally true and relies entirely on the fan-out's own address
    /// list already being scoped to that recipient set.
    /// </summary>
    public static Task<SosSessionDto> ProjectForRecipientAudienceAsync(
        IApplicationDbContext db,
        SosSession session,
        CancellationToken cancellationToken) =>
        ProjectCoreAsync(db, session, phoneNumberVisible: true, cancellationToken);

    private static async Task<SosSessionDto> ProjectCoreAsync(
        IApplicationDbContext db,
        SosSession session,
        bool phoneNumberVisible,
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

        string? senderPhoneNumberE164 = null;
        if (phoneNumberVisible)
        {
            senderPhoneNumberE164 = await db.Users
                .Where(u => u.Id == session.TriggeredByUserId)
                .Select(u => u.PhoneNumberE164)
                .SingleOrDefaultAsync(cancellationToken);
        }

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
            recipients,
            senderPhoneNumberE164);
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
