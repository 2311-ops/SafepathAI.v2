using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class FamilyInvitationTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    private static async Task<Guid> SeedFamilyWithGuardian(SafePath.Infrastructure.Persistence.ApplicationDbContext db, Guid guardianId)
    {
        var familyId = Guid.NewGuid();
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
        await db.SaveChangesAsync();
        return familyId;
    }

    [Fact]
    public async Task GenerateInvite_ByGuardian_CreatesPendingInviteWithCodeAndLinkToken()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);

        var handler = new GenerateInviteCommandHandler(db, new FamilyAuthorizationService(db), new InviteCodeGenerator());
        var result = await handler.Handle(new GenerateInviteCommand(guardianId, familyId, "Jordan"));

        Assert.NotEmpty(result.Code);
        Assert.NotEmpty(result.LinkToken);
        Assert.NotEqual(result.Code, result.LinkToken);
        Assert.True(result.ExpiresAt > DateTime.UtcNow.AddHours(23));
        Assert.True(result.ExpiresAt < DateTime.UtcNow.AddHours(25));

        var invitation = db.FamilyInvitations.Single(i => i.Id == result.InvitationId);
        Assert.Equal(InvitationStatus.Pending, invitation.Status);
    }

    [Fact]
    public async Task GenerateInvite_ByNonMember_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);
        var outsiderId = Guid.NewGuid();

        var handler = new GenerateInviteCommandHandler(db, new FamilyAuthorizationService(db), new InviteCodeGenerator());

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new GenerateInviteCommand(outsiderId, familyId, null)));
    }

    [Fact]
    public async Task RedeemInvite_Accept_TransitionsToAcceptedAndInsertsMembership()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);
        var generateHandler = new GenerateInviteCommandHandler(db, new FamilyAuthorizationService(db), new InviteCodeGenerator());
        var invite = await generateHandler.Handle(new GenerateInviteCommand(guardianId, familyId, null));

        var inviteeId = Guid.NewGuid();
        var redeemHandler = new RedeemInviteCommandHandler(db);
        var result = await redeemHandler.Handle(new RedeemInviteCommand(inviteeId, invite.Code, null, Accept: true));

        Assert.Equal(InvitationStatus.Accepted, result.Status);
        Assert.Equal(familyId, result.FamilyId);

        var membership = db.FamilyMembers.Single(m => m.FamilyId == familyId && m.UserId == inviteeId);
        Assert.Equal(Role.Member, membership.Role);
    }

    [Fact]
    public async Task RedeemInvite_SameCodeTwice_SecondRedeemIsRejected()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);
        var generateHandler = new GenerateInviteCommandHandler(db, new FamilyAuthorizationService(db), new InviteCodeGenerator());
        var invite = await generateHandler.Handle(new GenerateInviteCommand(guardianId, familyId, null));

        var redeemHandler = new RedeemInviteCommandHandler(db);
        await redeemHandler.Handle(new RedeemInviteCommand(Guid.NewGuid(), invite.Code, null, Accept: true));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => redeemHandler.Handle(new RedeemInviteCommand(Guid.NewGuid(), invite.Code, null, Accept: true)));
    }

    [Fact]
    public async Task RedeemInvite_Expired_IsRejected()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);
        db.FamilyInvitations.Add(new FamilyInvitation
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            Code = "SP-EXPIRD",
            LinkToken = "expired-token",
            CreatedByUserId = guardianId,
            ExpiresAt = DateTime.UtcNow.AddHours(-1),
            Status = InvitationStatus.Pending,
        });
        await db.SaveChangesAsync();

        var redeemHandler = new RedeemInviteCommandHandler(db);

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => redeemHandler.Handle(new RedeemInviteCommand(Guid.NewGuid(), "SP-EXPIRD", null, Accept: true)));
    }

    [Fact]
    public async Task RedeemInvite_Decline_TransitionsToDeclinedAndCreatesNoMembership()
    {
        await using var db = _factory.CreateContext();
        var guardianId = Guid.NewGuid();
        var familyId = await SeedFamilyWithGuardian(db, guardianId);
        var generateHandler = new GenerateInviteCommandHandler(db, new FamilyAuthorizationService(db), new InviteCodeGenerator());
        var invite = await generateHandler.Handle(new GenerateInviteCommand(guardianId, familyId, null));

        var inviteeId = Guid.NewGuid();
        var redeemHandler = new RedeemInviteCommandHandler(db);
        var result = await redeemHandler.Handle(new RedeemInviteCommand(inviteeId, invite.Code, null, Accept: false));

        Assert.Equal(InvitationStatus.Declined, result.Status);
        Assert.False(db.FamilyMembers.Any(m => m.FamilyId == familyId && m.UserId == inviteeId));
    }

    public void Dispose() => _factory.Dispose();
}
