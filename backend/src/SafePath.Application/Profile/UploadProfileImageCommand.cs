using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Entities;

namespace SafePath.Application.Profile;

public record UploadProfileImageCommand(Guid CallerUserId, byte[] RawBytes);

public class UploadProfileImageCommandHandler : ICommandHandler<UploadProfileImageCommand, GetMeResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IProfileImageValidator _validator;
    private readonly IProfileImageStorage _storage;
    private readonly ProfileImageUrlFactory? _profileImageUrlFactory;
    private readonly ILocationBroadcastService? _broadcast;

    public UploadProfileImageCommandHandler(
        IApplicationDbContext db,
        IProfileImageValidator validator,
        IProfileImageStorage storage,
        ProfileImageUrlFactory? profileImageUrlFactory = null,
        ILocationBroadcastService? broadcast = null)
    {
        _db = db;
        _validator = validator;
        _storage = storage;
        _profileImageUrlFactory = profileImageUrlFactory;
        _broadcast = broadcast;
    }

    public async Task<GetMeResult> Handle(UploadProfileImageCommand command, CancellationToken cancellationToken = default)
    {
        var user = await LoadUser(command.CallerUserId, cancellationToken);
        var validated = _validator.Validate(command.RawBytes);

        await _storage.UploadAvatarAsync(command.CallerUserId, validated.JpegBytes, cancellationToken);

        user.ProfileImagePath = _storage.GetAvatarObjectPath(command.CallerUserId);
        user.ProfileUpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        var profileImageUrl = _profileImageUrlFactory is null
            ? await _storage.CreateSignedAvatarUrlAsync(user.ProfileImagePath, ProfileImageUrlFactory.SignedUrlTtl, cancellationToken)
            : await _profileImageUrlFactory.SignAsync(user.ProfileImagePath, cancellationToken);
        await ProfileProjection.BroadcastUpdatedAsync(
            _db,
            _broadcast,
            _profileImageUrlFactory,
            user,
            profileImageUrl,
            cancellationToken);

        return ProfileProjection.FromUser(user, profileImageUrl);
    }

    private async Task<User> LoadUser(Guid userId, CancellationToken cancellationToken)
    {
        return await _db.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new InvalidOperationException($"User {userId} was not found.");
    }
}
