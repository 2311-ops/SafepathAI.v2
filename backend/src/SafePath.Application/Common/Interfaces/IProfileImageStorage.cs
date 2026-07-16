namespace SafePath.Application.Common.Interfaces;

public interface IProfileImageStorage
{
    Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default);
    Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default);
    string GetAvatarObjectPath(Guid userId);
}
