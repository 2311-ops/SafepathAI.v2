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

    public Task<RedeemInviteResult> Handle(RedeemInviteCommand command, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 Task 2 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }
}
