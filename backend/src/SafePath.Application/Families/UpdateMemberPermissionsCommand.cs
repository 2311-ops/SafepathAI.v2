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

    public async Task<UpdateMemberPermissionsResult> Handle(UpdateMemberPermissionsCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        // Re-scoped to command.FamilyId — never trust that MemberId alone identifies the
        // correct family (IDOR prevention, locked decision D5): a memberId belonging to a
        // different family is treated as "not found in this family", not silently updated.
        var target = await _db.FamilyMembers.SingleOrDefaultAsync(
            m => m.Id == command.MemberId && m.FamilyId == command.FamilyId && m.IsActive,
            cancellationToken);

        if (target is null)
        {
            throw new FamilyAuthorizationDeniedException(
                $"FamilyMember {command.MemberId} is not an active member of family {command.FamilyId}.");
        }

        target.Permissions = command.Permissions;
        await _db.SaveChangesAsync(cancellationToken);

        return new UpdateMemberPermissionsResult(target.Id, target.Permissions);
    }
}
