using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Location;
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

    public static async Task BroadcastUpdatedAsync(
        IApplicationDbContext db,
        ILocationBroadcastService? broadcast,
        ProfileImageUrlFactory? profileImageUrlFactory,
        User user,
        string? profileImageUrl,
        CancellationToken cancellationToken)
    {
        if (broadcast is null)
        {
            return;
        }

        var familyId = await db.FamilyMembers
            .Where(m => m.UserId == user.Id && m.IsActive)
            .OrderBy(m => m.JoinedAt)
            .Select(m => (Guid?)m.FamilyId)
            .FirstOrDefaultAsync(cancellationToken);

        if (familyId is null)
        {
            return;
        }

        var signedUrl = profileImageUrl;
        if (signedUrl is null && user.ProfileImagePath is not null && profileImageUrlFactory is not null)
        {
            signedUrl = await profileImageUrlFactory.SignAsync(user.ProfileImagePath, cancellationToken);
        }

        await broadcast.BroadcastProfileUpdated(
            familyId.Value,
            new ProfileUpdateDto(
                user.Id,
                string.IsNullOrWhiteSpace(user.DisplayName) ? user.FullName : user.DisplayName,
                signedUrl),
            cancellationToken);
    }
}
