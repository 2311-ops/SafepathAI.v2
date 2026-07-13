using SafePath.Application.Families;
using SafePath.Domain.Entities;

namespace SafePath.Application.Profile;

internal static class ProfileProjection
{
    public static GetMeResult FromUser(User user, string? profileImageUrl)
    {
        return new GetMeResult(
            user.Id,
            user.Role,
            user.Email,
            user.FullName,
            string.IsNullOrWhiteSpace(user.DisplayName) ? user.FullName : user.DisplayName,
            profileImageUrl,
            user.ProfileUpdatedAt);
    }
}
