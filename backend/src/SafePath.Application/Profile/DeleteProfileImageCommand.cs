using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Entities;

namespace SafePath.Application.Profile;

public record DeleteProfileImageCommand(Guid CallerUserId);

public class DeleteProfileImageCommandHandler : ICommandHandler<DeleteProfileImageCommand, GetMeResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IProfileImageStorage _storage;
    private readonly ILocationBroadcastService? _broadcast;

    public DeleteProfileImageCommandHandler(
        IApplicationDbContext db,
        IProfileImageStorage storage,
        ILocationBroadcastService? broadcast = null)
    {
        _db = db;
        _storage = storage;
        _broadcast = broadcast;
    }

    public async Task<GetMeResult> Handle(DeleteProfileImageCommand command, CancellationToken cancellationToken = default)
    {
        var user = await LoadUser(command.CallerUserId, cancellationToken);

        await _storage.DeleteAvatarAsync(command.CallerUserId, cancellationToken);
        user.ProfileImagePath = null;
        user.ProfileUpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);
        await ProfileProjection.BroadcastUpdatedAsync(
            _db,
            _broadcast,
            profileImageUrlFactory: null,
            user,
            profileImageUrl: null,
            cancellationToken);

        return ProfileProjection.FromUser(user, profileImageUrl: null);
    }

    private async Task<User> LoadUser(Guid userId, CancellationToken cancellationToken)
    {
        return await _db.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new InvalidOperationException($"User {userId} was not found.");
    }
}
