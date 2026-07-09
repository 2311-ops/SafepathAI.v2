using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record TransferOwnershipCommand(Guid CallerUserId, Guid FamilyId, Guid NewGuardianMemberId);

public record TransferOwnershipResult(Guid NewGuardianMemberId);

public class TransferOwnershipCommandHandler : ICommandHandler<TransferOwnershipCommand, TransferOwnershipResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public TransferOwnershipCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<TransferOwnershipResult> Handle(TransferOwnershipCommand command, CancellationToken cancellationToken = default)
    {
        var callerMembership = await _authorization.RequireRole(
            command.CallerUserId,
            command.FamilyId,
            Role.Guardian,
            cancellationToken);

        var target = await _db.FamilyMembers.SingleOrDefaultAsync(
            m => m.Id == command.NewGuardianMemberId && m.FamilyId == command.FamilyId && m.IsActive,
            cancellationToken);

        if (target is null)
        {
            throw new FamilyAuthorizationDeniedException(
                $"FamilyMember {command.NewGuardianMemberId} is not an active member of family {command.FamilyId}.");
        }

        if (target.Id == callerMembership.Id)
        {
            throw new InvalidOperationException("Transfer ownership to a different active member.");
        }

        target.Role = Role.Guardian;
        target.Permissions = PermissionLevel.FullLocation;
        callerMembership.Role = Role.Member;
        callerMembership.Permissions = PermissionLevel.ViewOnly;

        await _db.SaveChangesAsync(cancellationToken);

        return new TransferOwnershipResult(target.Id);
    }
}
