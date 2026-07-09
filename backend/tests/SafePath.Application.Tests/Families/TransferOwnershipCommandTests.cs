using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class TransferOwnershipCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_ByGuardian_TransfersRoleAndPermissions()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamilyWithGuardianAndMember(db);
        var handler = new TransferOwnershipCommandHandler(db, new FamilyAuthorizationService(db));

        await handler.Handle(new TransferOwnershipCommand(seed.GuardianUserId, seed.FamilyId, seed.MemberRowId));

        var guardianRow = db.FamilyMembers.Single(m => m.Id == seed.GuardianRowId);
        var memberRow = db.FamilyMembers.Single(m => m.Id == seed.MemberRowId);
        Assert.Equal(Role.Member, guardianRow.Role);
        Assert.Equal(PermissionLevel.ViewOnly, guardianRow.Permissions);
        Assert.Equal(Role.Guardian, memberRow.Role);
        Assert.Equal(PermissionLevel.FullLocation, memberRow.Permissions);
    }

    [Fact]
    public async Task Handle_ByNonGuardian_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamilyWithGuardianAndMember(db);
        var handler = new TransferOwnershipCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new TransferOwnershipCommand(seed.MemberUserId, seed.FamilyId, seed.GuardianRowId)));
    }

    [Fact]
    public async Task Handle_CrossFamilyTarget_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var seedA = await SeedFamilyWithGuardianAndMember(db);
        var seedB = await SeedFamilyWithGuardianAndMember(db);
        var handler = new TransferOwnershipCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new TransferOwnershipCommand(seedA.GuardianUserId, seedA.FamilyId, seedB.MemberRowId)));
    }

    [Fact]
    public async Task Handle_InactiveTarget_IsRejected()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamilyWithGuardianAndMember(db);
        db.FamilyMembers.Single(m => m.Id == seed.MemberRowId).IsActive = false;
        await db.SaveChangesAsync();
        var handler = new TransferOwnershipCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new TransferOwnershipCommand(seed.GuardianUserId, seed.FamilyId, seed.MemberRowId)));
    }

    [Fact]
    public async Task Handle_SelfTransfer_IsRejected()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamilyWithGuardianAndMember(db);
        var handler = new TransferOwnershipCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => handler.Handle(new TransferOwnershipCommand(seed.GuardianUserId, seed.FamilyId, seed.GuardianRowId)));
    }

    private static async Task<SeedResult> SeedFamilyWithGuardianAndMember(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var guardianUserId = Guid.NewGuid();
        var memberUserId = Guid.NewGuid();
        var guardianRow = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = guardianUserId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };
        var memberRow = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = memberUserId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = guardianUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(guardianRow, memberRow);
        await db.SaveChangesAsync();
        return new SeedResult(familyId, guardianUserId, memberUserId, guardianRow.Id, memberRow.Id);
    }

    private record SeedResult(Guid FamilyId, Guid GuardianUserId, Guid MemberUserId, Guid GuardianRowId, Guid MemberRowId);

    public void Dispose() => _factory.Dispose();
}
