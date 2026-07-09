using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record RevokeInviteCommand(Guid CallerUserId, Guid FamilyId, Guid InvitationId);

public record RevokeInviteResult(Guid InvitationId, InvitationStatus Status);

public class RevokeInviteCommandHandler : ICommandHandler<RevokeInviteCommand, RevokeInviteResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public RevokeInviteCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<RevokeInviteResult> Handle(RevokeInviteCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(command.CallerUserId, command.FamilyId, Role.Guardian, cancellationToken);

        var invitation = await _db.FamilyInvitations.SingleOrDefaultAsync(
            i => i.Id == command.InvitationId && i.FamilyId == command.FamilyId,
            cancellationToken);

        if (invitation is null)
        {
            throw new FamilyAuthorizationDeniedException(
                $"Invitation {command.InvitationId} is not in family {command.FamilyId}.");
        }

        if (invitation.Status != InvitationStatus.Pending)
        {
            throw new InvalidOperationException($"Only Pending invitations can be revoked. Current status: {invitation.Status}.");
        }

        invitation.Status = InvitationStatus.Revoked;
        await _db.SaveChangesAsync(cancellationToken);

        return new RevokeInviteResult(invitation.Id, invitation.Status);
    }
}
