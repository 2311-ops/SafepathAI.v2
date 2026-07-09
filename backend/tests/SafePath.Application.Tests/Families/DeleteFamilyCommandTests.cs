using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class DeleteFamilyCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_ByGuardian_RemovesFamilyMembersAndInvitations()
    {
        await using var db = _factory.CreateContext();
        var (familyId, guardianId, _) = await SeedFamily(db);
        var handler = new DeleteFamilyCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new DeleteFamilyCommand(guardianId, familyId));

        Assert.False(db.Families.Any(f => f.Id == familyId));
        Assert.False(db.FamilyMembers.Any(m => m.FamilyId == familyId));
        Assert.False(db.FamilyInvitations.Any(i => i.FamilyId == familyId));
    }

    [Fact]
    public async Task Handle_ByMember_IsDeniedAndDeletesNothing()
    {
        await using var db = _factory.CreateContext();
        var (familyId, _, memberId) = await SeedFamily(db);
        var handler = new DeleteFamilyCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new DeleteFamilyCommand(memberId, familyId)));

        Assert.True(db.Families.Any(f => f.Id == familyId));
        Assert.True(db.FamilyMembers.Any(m => m.FamilyId == familyId));
        Assert.True(db.FamilyInvitations.Any(i => i.FamilyId == familyId));
    }

    [Fact]
    public async Task Handle_OnlyDeletesTargetFamily()
    {
        await using var db = _factory.CreateContext();
        var (targetFamilyId, guardianId, _) = await SeedFamily(db);
        var (otherFamilyId, _, _) = await SeedFamily(db);
        var handler = new DeleteFamilyCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new DeleteFamilyCommand(guardianId, targetFamilyId));

        Assert.False(db.Families.Any(f => f.Id == targetFamilyId));
        Assert.True(db.Families.Any(f => f.Id == otherFamilyId));
        Assert.True(db.FamilyMembers.Any(m => m.FamilyId == otherFamilyId));
        Assert.True(db.FamilyInvitations.Any(i => i.FamilyId == otherFamilyId));
    }

    private static async Task<(Guid FamilyId, Guid GuardianId, Guid MemberId)> SeedFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = guardianId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow,
                IsActive = true,
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = memberId,
                Role = Role.Member,
                Permissions = PermissionLevel.ViewOnly,
                JoinedAt = DateTime.UtcNow,
                IsActive = true,
            });
        db.FamilyInvitations.Add(new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            Code = $"SP-{Guid.NewGuid():N}"[..9].ToUpperInvariant(),
            LinkToken = Guid.NewGuid().ToString("N"),
            CreatedByUserId = guardianId,
            ExpiresAt = DateTime.UtcNow.AddHours(1),
            Status = InvitationStatus.Pending,
        });
        await db.SaveChangesAsync();
        return (familyId, guardianId, memberId);
    }

    public void Dispose() => _factory.Dispose();
}
