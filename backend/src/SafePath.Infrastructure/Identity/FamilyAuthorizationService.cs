using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Infrastructure.Identity;

/// <summary>
/// Server-side membership + role re-check (locked decision D5) — the primary authorization
/// mechanism for every family-scoped command/query. Always queries the caller's own active
/// FamilyMember row for the family in question; never trusts a client-supplied familyId or
/// role claim.
/// </summary>
public class FamilyAuthorizationService : IFamilyAuthorizationService
{
    private readonly IApplicationDbContext _db;

    public FamilyAuthorizationService(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<FamilyMember> RequireMembership(Guid userId, Guid familyId, CancellationToken cancellationToken = default)
    {
        var member = await _db.FamilyMembers
            .SingleOrDefaultAsync(m => m.FamilyId == familyId && m.UserId == userId && m.IsActive, cancellationToken);

        if (member is null)
        {
            throw new FamilyAuthorizationDeniedException(
                $"User {userId} is not an active member of family {familyId}.");
        }

        return member;
    }

    public async Task<FamilyMember> RequireRole(Guid userId, Guid familyId, Role role, CancellationToken cancellationToken = default)
    {
        var member = await RequireMembership(userId, familyId, cancellationToken);

        if (member.Role != role)
        {
            throw new FamilyAuthorizationDeniedException(
                $"User {userId} has role {member.Role} in family {familyId}, but {role} is required.");
        }

        return member;
    }
}
