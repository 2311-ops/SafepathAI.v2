using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record FamilyMemberDto(Guid Id, Guid UserId, Role Role, PermissionLevel Permissions, DateTime JoinedAt);

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

        return await _db.FamilyMembers
            .Where(m => m.FamilyId == query.FamilyId && m.IsActive)
            .OrderBy(m => m.JoinedAt)
            .Select(m => new FamilyMemberDto(m.Id, m.UserId, m.Role, m.Permissions, m.JoinedAt))
            .ToListAsync(cancellationToken);
    }
}
