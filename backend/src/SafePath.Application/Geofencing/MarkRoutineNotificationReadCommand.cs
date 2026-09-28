using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Geofencing;

/// <summary>Marks one recipient-owned feed row as read without changing its durable activity.</summary>
public sealed record MarkRoutineNotificationReadCommand(Guid RecipientUserId, Guid FeedItemId);

public sealed class MarkRoutineNotificationReadCommandHandler
    : ICommandHandler<MarkRoutineNotificationReadCommand, bool>
{
    private readonly IApplicationDbContext _db;

    public MarkRoutineNotificationReadCommandHandler(IApplicationDbContext db) => _db = db;

    public async Task<bool> Handle(
        MarkRoutineNotificationReadCommand command,
        CancellationToken cancellationToken = default)
    {
        if (command.RecipientUserId == Guid.Empty || command.FeedItemId == Guid.Empty)
            throw new ArgumentException("Recipient and notification are required.", nameof(command));

        var item = await _db.GeofenceFeedItems.SingleOrDefaultAsync(
            candidate => candidate.Id == command.FeedItemId && candidate.RecipientUserId == command.RecipientUserId,
            cancellationToken);
        if (item is null)
            return false;

        item.ReadAtUtc ??= DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}
