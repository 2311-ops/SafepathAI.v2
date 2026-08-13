using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Storage;

public sealed class DisabledProfileImageStorage : IProfileImageStorage
{
    private const string AvatarFileName = "avatar.jpg";

    public Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default)
    {
        throw new ProfileImageStorageNotConfiguredException();
    }

    public Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        throw new ProfileImageStorageNotConfiguredException();
    }

    public Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default)
    {
        throw new ProfileImageStorageNotConfiguredException();
    }

    public string GetAvatarObjectPath(Guid userId)
    {
        return $"avatars/{userId:D}/{AvatarFileName}";
    }
}
