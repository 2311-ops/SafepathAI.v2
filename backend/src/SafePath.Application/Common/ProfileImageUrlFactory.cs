using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Common;

public class ProfileImageUrlFactory
{
    public static readonly TimeSpan SignedUrlTtl = TimeSpan.FromHours(1);

    private readonly IProfileImageStorage _storage;

    public ProfileImageUrlFactory(IProfileImageStorage storage)
    {
        _storage = storage;
    }

    public Task<string?> SignAsync(string? profileImagePath, CancellationToken cancellationToken = default)
    {
        return string.IsNullOrWhiteSpace(profileImagePath)
            ? Task.FromResult<string?>(null)
            : SignPathAsync(profileImagePath, cancellationToken);
    }

    private async Task<string?> SignPathAsync(string profileImagePath, CancellationToken cancellationToken)
    {
        return await _storage.CreateSignedAvatarUrlAsync(profileImagePath, SignedUrlTtl, cancellationToken);
    }
}
