using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

/// <summary>
/// Accepts or declines a Pending invite by short display <see cref="Code"/> or the longer
/// opaque <see cref="LinkToken"/> (FAM-03). Requires an authenticated caller — the invite is
/// never redeemable anonymously.
/// </summary>
public record RedeemInviteCommand(Guid UserId, string? Code, string? LinkToken, bool Accept);

public record RedeemInviteResult(Guid FamilyId, InvitationStatus Status);

public class RedeemInviteCommandHandler : ICommandHandler<RedeemInviteCommand, RedeemInviteResult>
{
    private readonly IApplicationDbContext _db;

    public RedeemInviteCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<RedeemInviteResult> Handle(RedeemInviteCommand command, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(command.Code) && string.IsNullOrWhiteSpace(command.LinkToken))
        {
            throw new ArgumentException("Either a code or a link token is required.", nameof(command));
        }

        var invitation = !string.IsNullOrWhiteSpace(command.LinkToken)
            ? await _db.FamilyInvitations.SingleOrDefaultAsync(i => i.LinkToken == command.LinkToken, cancellationToken)
            : await _db.FamilyInvitations.SingleOrDefaultAsync(i => i.Code == command.Code, cancellationToken);

        if (invitation is null)
        {
            throw new InvalidOperationException("Invite not found.");
        }

        if (invitation.Status != InvitationStatus.Pending)
        {
            throw new InvalidOperationException($"Invite is already {invitation.Status}.");
        }

        if (invitation.ExpiresAt < DateTime.UtcNow)
        {
            invitation.Status = InvitationStatus.Expired;
            await _db.SaveChangesAsync(cancellationToken);
            throw new InvalidOperationException("Invite has expired.");
        }

        if (command.Accept)
        {
            invitation.Status = InvitationStatus.Accepted;
            invitation.AcceptedByUserId = command.UserId;

            _db.FamilyMembers.Add(new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = invitation.FamilyId,
                UserId = command.UserId,
                Role = Role.Member,
                Permissions = PermissionLevel.ViewOnly,
                JoinedAt = DateTime.UtcNow,
                IsActive = true,
            });
        }
        else
        {
            invitation.Status = InvitationStatus.Declined;
        }

        // Status flip + (on accept) FamilyMember insert commit in one SaveChangesAsync — the
        // check-then-set above plus this single transaction is the "atomic" single-use
        // enforcement (RESEARCH Pitfall 4); no external actor can observe a Pending invite
        // become Accepted without a membership row also existing.
        await _db.SaveChangesAsync(cancellationToken);

        return new RedeemInviteResult(invitation.FamilyId, invitation.Status);
    }
}
