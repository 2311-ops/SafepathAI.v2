using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Profile;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record GetMeQuery(Guid UserId);

public record GetMeResult(
    Guid UserId,
    Role? Role,
    string? Email,
    string? FullName,
    string? DisplayName = null,
    string? ProfileImageUrl = null,
    DateTime? ProfileUpdatedAt = null);

public class GetMeQueryHandler : ICommandHandler<GetMeQuery, GetMeResult>
{
    private readonly IApplicationDbContext _db;
    private readonly ProfileImageUrlFactory? _profileImageUrlFactory;

    public GetMeQueryHandler(IApplicationDbContext db, ProfileImageUrlFactory? profileImageUrlFactory = null)
    {
        _db = db;
        _profileImageUrlFactory = profileImageUrlFactory;
    }

    public async Task<GetMeResult> Handle(GetMeQuery command, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.SingleOrDefaultAsync(u => u.Id == command.UserId, cancellationToken);
        if (user is null)
        {
            return new GetMeResult(command.UserId, null, null, null);
        }

        var profileImageUrl = _profileImageUrlFactory is null
            ? null
            : await _profileImageUrlFactory.SignAsync(user.ProfileImagePath, cancellationToken);

        return ProfileProjection.FromUser(user, profileImageUrl);
    }
}
