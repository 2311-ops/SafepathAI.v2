using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

/// <summary>Generates a Pending, 24h-expiring, single-use family invite. Guardian-gated (FAM-02).</summary>
public record GenerateInviteCommand(Guid UserId, Guid FamilyId, string? InviteeLabel);

public record GenerateInviteResult(Guid InvitationId, string Code, string LinkToken, DateTime ExpiresAt);

public class GenerateInviteCommandHandler : ICommandHandler<GenerateInviteCommand, GenerateInviteResult>
{
    private const int MaxCodeCollisionAttempts = 5;

    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IInviteCodeGenerator _codeGenerator;

    public GenerateInviteCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IInviteCodeGenerator codeGenerator)
    {
        _db = db;
        _authorization = authorization;
        _codeGenerator = codeGenerator;
    }

    public async Task<GenerateInviteResult> Handle(GenerateInviteCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireRole(command.UserId, command.FamilyId, Role.Guardian, cancellationToken);

        var code = await GenerateUniqueDisplayCode(cancellationToken);
        var invitation = new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = command.FamilyId,
            Code = code,
            LinkToken = _codeGenerator.GenerateLinkToken(),
            InviteeLabel = command.InviteeLabel,
            CreatedByUserId = command.UserId,
            ExpiresAt = DateTime.UtcNow.AddHours(24),
            Status = InvitationStatus.Pending,
        };

        _db.FamilyInvitations.Add(invitation);
        await _db.SaveChangesAsync(cancellationToken);

        return new GenerateInviteResult(invitation.Id, invitation.Code, invitation.LinkToken, invitation.ExpiresAt);
    }

    private async Task<string> GenerateUniqueDisplayCode(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < MaxCodeCollisionAttempts; attempt++)
        {
            var candidate = _codeGenerator.GenerateDisplayCode();
            var exists = await _db.FamilyInvitations.AnyAsync(i => i.Code == candidate, cancellationToken);
            if (!exists)
            {
                return candidate;
            }
        }

        throw new InvalidOperationException("Could not generate a unique invite code.");
    }
}
