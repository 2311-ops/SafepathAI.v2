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

    public Task<FamilyMember> RequireMembership(Guid userId, Guid familyId, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }

    public Task<FamilyMember> RequireRole(Guid userId, Guid familyId, Role role, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }
}
