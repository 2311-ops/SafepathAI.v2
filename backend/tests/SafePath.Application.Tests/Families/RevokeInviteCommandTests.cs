using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class RevokeInviteCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_ByGuardian_RevokesPendingInvite()
    {
        await using var db = _factory.CreateContext();
        var (familyId, guardianId, inviteId) = await SeedFamilyWithInvite(db);
        var handler = new RevokeInviteCommandHandler(db, new FamilyAuthorizationService(db));

        var result = await handler.Handle(new RevokeInviteCommand(guardianId, familyId, inviteId));

        Assert.Equal(InvitationStatus.Revoked, result.Status);
        Assert.Equal(InvitationStatus.Revoked, db.FamilyInvitations.Single(i => i.Id == inviteId).Status);
    }

    [Fact]
    public async Task Handle_ByMember_IsDeniedAndLeavesPending()
    {
        await using var db = _factory.CreateContext();
        var (familyId, _, inviteId) = await SeedFamilyWithInvite(db);
        var memberId = Guid.NewGuid();
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = memberId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        await db.SaveChangesAsync();
        var handler = new RevokeInviteCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new RevokeInviteCommand(memberId, familyId, inviteId)));

        Assert.Equal(InvitationStatus.Pending, db.FamilyInvitations.Single(i => i.Id == inviteId).Status);
    }

    [Fact]
    public async Task Handle_CrossFamilyInvite_IsDeniedAndLeavesPending()
    {
        await using var db = _factory.CreateContext();
        var (familyAId, guardianAId, _) = await SeedFamilyWithInvite(db);
        var (_, _, inviteBId) = await SeedFamilyWithInvite(db);
        var handler = new RevokeInviteCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new RevokeInviteCommand(guardianAId, familyAId, inviteBId)));

        Assert.Equal(InvitationStatus.Pending, db.FamilyInvitations.Single(i => i.Id == inviteBId).Status);
    }

    [Fact]
    public async Task Handle_NonPendingInvite_IsRejected()
    {
        await using var db = _factory.CreateContext();
        var (familyId, guardianId, inviteId) = await SeedFamilyWithInvite(db, InvitationStatus.Accepted);
        var handler = new RevokeInviteCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => handler.Handle(new RevokeInviteCommand(guardianId, familyId, inviteId)));
    }

    private static async Task<(Guid FamilyId, Guid GuardianId, Guid InviteId)> SeedFamilyWithInvite(
        ApplicationDbContext db,
        InvitationStatus status = InvitationStatus.Pending)
    {
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = guardianId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        var invite = new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            Code = $"SP-{Guid.NewGuid():N}"[..9].ToUpperInvariant(),
            LinkToken = Guid.NewGuid().ToString("N"),
            CreatedByUserId = guardianId,
            ExpiresAt = DateTime.UtcNow.AddHours(1),
            Status = status,
        };
        db.FamilyInvitations.Add(invite);
        await db.SaveChangesAsync();
        return (familyId, guardianId, invite.Id);
    }

    public void Dispose() => _factory.Dispose();
}
