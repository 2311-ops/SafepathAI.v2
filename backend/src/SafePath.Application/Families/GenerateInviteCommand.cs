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

    public Task<GenerateInviteResult> Handle(GenerateInviteCommand command, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 Task 2 TDD RED/GREEN cycle.
        throw new NotImplementedException();
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
