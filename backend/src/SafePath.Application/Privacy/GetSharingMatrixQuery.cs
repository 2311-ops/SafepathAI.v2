using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Privacy;

public record GetSharingMatrixQuery(Guid CallerUserId, Guid FamilyId);

public class GetSharingMatrixQueryHandler : ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public GetSharingMatrixQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<SharingMatrixDto> Handle(GetSharingMatrixQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(query.CallerUserId, query.FamilyId, cancellationToken);

        var entries = await (
            from preference in _db.SharingPreferences
            join recipientMember in _db.FamilyMembers on preference.RecipientMemberId equals recipientMember.Id into recipients
            from recipientMember in recipients.DefaultIfEmpty()
            join user in _db.Users on recipientMember.UserId equals user.Id into users
            from user in users.DefaultIfEmpty()
            where preference.FamilyId == query.FamilyId && preference.OwnerUserId == query.CallerUserId
            orderby preference.RecipientMemberId == null ? 0 : 1, user.FullName, preference.DataType
            select new SharingPreferenceDto(
                preference.RecipientMemberId,
                user.FullName,
                preference.DataType,
                preference.IsEnabled,
                preference.ExpiresAtUtc))
            .ToListAsync(cancellationToken);

        return new SharingMatrixDto(entries);
    }
}
