using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class SingleFamilyInvariantTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task CreateFamily_WhenUserHasActiveMembership_ThrowsAndInsertsNothing()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        await SeedFamilyWithMembership(db, userId, Role.Member, PermissionLevel.ViewOnly);
        var startingFamilyCount = db.Families.Count();
        var startingMembershipCount = db.FamilyMembers.Count();

        var handler = new CreateFamilyCommandHandler(db);

        await Assert.ThrowsAsync<AlreadyInAnotherFamilyException>(
            () => handler.Handle(new CreateFamilyCommand(userId, "Second Circle")));

        Assert.Equal(startingFamilyCount, db.Families.Count());
        Assert.Equal(startingMembershipCount, db.FamilyMembers.Count());
    }

    [Fact]
    public async Task RedeemInvite_WhenUserHasActiveMembership_ThrowsLeavesInvitePendingAndInsertsNothing()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        await SeedFamilyWithMembership(db, userId, Role.Member, PermissionLevel.ViewOnly);
        var invite = await SeedPendingInvite(db);
        var startingMembershipCount = db.FamilyMembers.Count();

        var handler = new RedeemInviteCommandHandler(db);

        await Assert.ThrowsAsync<AlreadyInAnotherFamilyException>(
            () => handler.Handle(new RedeemInviteCommand(userId, invite.Code, null, Accept: true)));

        Assert.Equal(InvitationStatus.Pending, db.FamilyInvitations.Single(i => i.Id == invite.Id).Status);
        Assert.Equal(startingMembershipCount, db.FamilyMembers.Count());
    }

    [Fact]
    public async Task RedeemInvite_ForRemovedSameFamilyMember_ReactivatesExistingMembership()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
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
        var removedMember = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = Role.Member,
            Permissions = PermissionLevel.NotificationOnly,
            JoinedAt = DateTime.UtcNow.AddDays(-5),
            IsActive = false,
            RemovedAt = DateTime.UtcNow.AddDays(-1),
        };
        db.FamilyMembers.Add(removedMember);
        var invite = new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            Code = "SP-REJOIN",
            LinkToken = "rejoin-token",
            CreatedByUserId = guardianId,
            ExpiresAt = DateTime.UtcNow.AddHours(1),
            Status = InvitationStatus.Pending,
        };
        db.FamilyInvitations.Add(invite);
        await db.SaveChangesAsync();
        var startingMembershipCount = db.FamilyMembers.Count();

        var handler = new RedeemInviteCommandHandler(db);
        var result = await handler.Handle(new RedeemInviteCommand(userId, invite.Code, null, Accept: true));

        Assert.Equal(InvitationStatus.Accepted, result.Status);
        Assert.Equal(startingMembershipCount, db.FamilyMembers.Count());
        var membership = db.FamilyMembers.Single(m => m.Id == removedMember.Id);
        Assert.True(membership.IsActive);
        Assert.Null(membership.RemovedAt);
        Assert.Equal(Role.Member, membership.Role);
        Assert.Equal(PermissionLevel.ViewOnly, membership.Permissions);
    }

    [Fact]
    public async Task RedeemInvite_ForFreshUser_InsertsOneMembership()
    {
        await using var db = _factory.CreateContext();
        var invite = await SeedPendingInvite(db);
        var userId = Guid.NewGuid();

        var handler = new RedeemInviteCommandHandler(db);
        await handler.Handle(new RedeemInviteCommand(userId, null, invite.LinkToken, Accept: true));

        var membership = db.FamilyMembers.Single(m => m.UserId == userId);
        Assert.Equal(invite.FamilyId, membership.FamilyId);
        Assert.True(membership.IsActive);
    }

    private static async Task<FamilyInvitation> SeedPendingInvite(ApplicationDbContext db)
    {
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithMembership(db, guardianId, Role.Guardian, PermissionLevel.FullLocation);
        var invite = new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            Code = $"SP-{Guid.NewGuid():N}"[..9].ToUpperInvariant(),
            LinkToken = Guid.NewGuid().ToString("N"),
            CreatedByUserId = guardianId,
            ExpiresAt = DateTime.UtcNow.AddHours(1),
            Status = InvitationStatus.Pending,
        };
        db.FamilyInvitations.Add(invite);
        await db.SaveChangesAsync();
        return invite;
    }

    private static async Task<Guid> SeedFamilyWithMembership(
        ApplicationDbContext db,
        Guid userId,
        Role role,
        PermissionLevel permissions)
    {
        var familyId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = role,
            Permissions = permissions,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        await db.SaveChangesAsync();
        return familyId;
    }

    public void Dispose() => _factory.Dispose();
}
