using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record FamilyMemberDto(
    Guid Id,
    Guid UserId,
    string DisplayName,
    Role Role,
    PermissionLevel Permissions,
    DateTime JoinedAt);

/// <summary>
/// Lists the active members of a family. Membership-gated: the caller must themselves be an
/// active member of the family before the roster is returned (IDOR prevention, locked decision D5).
/// </summary>
public record ListFamilyMembersQuery(Guid UserId, Guid FamilyId);

public class ListFamilyMembersQueryHandler : ICommandHandler<ListFamilyMembersQuery, IReadOnlyList<FamilyMemberDto>>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public ListFamilyMembersQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<IReadOnlyList<FamilyMemberDto>> Handle(ListFamilyMembersQuery query, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(query.UserId, query.FamilyId, cancellationToken);

        return await (
            from member in _db.FamilyMembers
            join user in _db.Users on member.UserId equals user.Id
            where member.FamilyId == query.FamilyId && member.IsActive
            orderby member.JoinedAt
            select new FamilyMemberDto(
                member.Id,
                member.UserId,
                string.IsNullOrWhiteSpace(user.DisplayName) ? user.FullName : user.DisplayName,
                member.Role,
                member.Permissions,
                member.JoinedAt))
            .ToListAsync(cancellationToken);
    }
}
