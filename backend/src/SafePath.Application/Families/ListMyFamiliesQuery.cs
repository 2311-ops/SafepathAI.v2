using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record MyFamilyDto(Guid FamilyId, string FamilyName, Role Role, PermissionLevel Permissions);

/// <summary>
/// Lists the caller's own active family memberships. Unlike <see cref="ListFamilyMembersQuery"/>,
/// this is not membership-gated to a specific family — the caller's own <c>UserId</c> claim
/// (never client input) is the only scoping input, so there is nothing to authorize beyond
/// "you can always see families you belong to" (locked decision D-10-2).
/// </summary>
public record ListMyFamiliesQuery(Guid UserId);

public class ListMyFamiliesQueryHandler : ICommandHandler<ListMyFamiliesQuery, IReadOnlyList<MyFamilyDto>>
{
    private readonly IApplicationDbContext _db;

    public ListMyFamiliesQueryHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<MyFamilyDto>> Handle(ListMyFamiliesQuery query, CancellationToken cancellationToken = default)
    {
        return await _db.FamilyMembers
            .Where(m => m.UserId == query.UserId && m.IsActive)
            .Join(_db.Families, m => m.FamilyId, f => f.Id, (m, f) => new { m.JoinedAt, Dto = new MyFamilyDto(f.Id, f.Name, m.Role, m.Permissions) })
            .OrderBy(x => x.JoinedAt)
            .Select(x => x.Dto)
            .ToListAsync(cancellationToken);
    }
}
