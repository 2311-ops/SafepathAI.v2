using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

/// <summary>Guardian-gated soft-removal of a family member (FAM-05).</summary>
public record RemoveMemberCommand(Guid CallerUserId, Guid FamilyId, Guid MemberId);

public record RemoveMemberResult(Guid MemberId, bool Removed);

public class RemoveMemberCommandHandler : ICommandHandler<RemoveMemberCommand, RemoveMemberResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public RemoveMemberCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public Task<RemoveMemberResult> Handle(RemoveMemberCommand command, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 Task 3 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }
}
