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

    public async Task<RemoveMemberResult> Handle(RemoveMemberCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        // Re-scoped to command.FamilyId — a Guardian of family A cannot remove a member of
        // family B by guessing/reusing a memberId (IDOR prevention, locked decision D5).
        var target = await _db.FamilyMembers.SingleOrDefaultAsync(
            m => m.Id == command.MemberId && m.FamilyId == command.FamilyId && m.IsActive,
            cancellationToken);

        if (target is null)
        {
            throw new FamilyAuthorizationDeniedException(
                $"FamilyMember {command.MemberId} is not an active member of family {command.FamilyId}.");
        }

        if (target.Role == Role.Guardian)
        {
            var activeGuardianCount = await _db.FamilyMembers.CountAsync(
                m => m.FamilyId == command.FamilyId && m.IsActive && m.Role == Role.Guardian,
                cancellationToken);

            if (activeGuardianCount <= 1)
            {
                throw new InvalidOperationException("Cannot remove the last active Guardian of a family.");
            }
        }

        target.IsActive = false;
        target.RemovedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        return new RemoveMemberResult(target.Id, true);
    }
}
