using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record DeleteFamilyCommand(Guid CallerUserId, Guid FamilyId);

public record DeleteFamilyResult(Guid FamilyId, bool Deleted);

public class DeleteFamilyCommandHandler : ICommandHandler<DeleteFamilyCommand, DeleteFamilyResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public DeleteFamilyCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<DeleteFamilyResult> Handle(DeleteFamilyCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        var family = await _db.Families.SingleOrDefaultAsync(f => f.Id == command.FamilyId, cancellationToken);
        if (family is null)
        {
            throw new FamilyAuthorizationDeniedException($"Family {command.FamilyId} was not found.");
        }

        var members = await _db.FamilyMembers.Where(m => m.FamilyId == command.FamilyId).ToListAsync(cancellationToken);
        var invitations = await _db.FamilyInvitations.Where(i => i.FamilyId == command.FamilyId).ToListAsync(cancellationToken);

        _db.FamilyMembers.RemoveRange(members);
        _db.FamilyInvitations.RemoveRange(invitations);
        _db.Families.Remove(family);

        await _db.SaveChangesAsync(cancellationToken);

        return new DeleteFamilyResult(command.FamilyId, true);
    }
}
