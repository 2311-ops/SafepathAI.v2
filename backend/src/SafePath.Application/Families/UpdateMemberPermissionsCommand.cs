using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

/// <summary>Guardian-gated update of a member's visibility permission level (FAM-04).</summary>
public record UpdateMemberPermissionsCommand(Guid CallerUserId, Guid FamilyId, Guid MemberId, PermissionLevel Permissions);

public record UpdateMemberPermissionsResult(Guid MemberId, PermissionLevel Permissions);

public class UpdateMemberPermissionsCommandHandler : ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public UpdateMemberPermissionsCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public Task<UpdateMemberPermissionsResult> Handle(UpdateMemberPermissionsCommand command, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 Task 3 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }
}
