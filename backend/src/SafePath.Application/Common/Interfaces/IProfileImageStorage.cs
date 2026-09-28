namespace SafePath.Application.Common.Interfaces;

public sealed class ProfileImageStorageNotConfiguredException : InvalidOperationException
{
    public ProfileImageStorageNotConfiguredException()
        : base("Supabase profile image storage is not configured. Set Supabase:ServiceRoleKey to enable avatar storage.")
    {
    }
}

public interface IProfileImageStorage
{
    Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default);
    Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default);
    string GetAvatarObjectPath(Guid userId);
}
