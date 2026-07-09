using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class UpdateMemberPermissionsCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    private static async Task<(Guid FamilyId, Guid GuardianId, Guid MemberRowId)> SeedFamilyWithMember(ApplicationDbContext db)
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
        var memberRow = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = Guid.NewGuid(),
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };
        db.FamilyMembers.Add(memberRow);
        await db.SaveChangesAsync();

        return (familyId, guardianId, memberRow.Id);
    }

    [Fact]
    public async Task Handle_ByGuardian_PersistsNewPermissionLevel()
    {
        await using var db = _factory.CreateContext();
        var (familyId, guardianId, memberRowId) = await SeedFamilyWithMember(db);
        var handler = new UpdateMemberPermissionsCommandHandler(db, new FamilyAuthorizationService(db));

        var result = await handler.Handle(new UpdateMemberPermissionsCommand(guardianId, familyId, memberRowId, PermissionLevel.NotificationOnly));

        Assert.Equal(PermissionLevel.NotificationOnly, result.Permissions);
        Assert.Equal(PermissionLevel.NotificationOnly, db.FamilyMembers.Single(m => m.Id == memberRowId).Permissions);
    }

    [Fact]
    public async Task Handle_ByNonGuardianMember_IsDenied()
    {
        await using var db = _factory.CreateContext();
        var (familyId, _, memberRowId) = await SeedFamilyWithMember(db);
        var nonGuardianId = Guid.NewGuid();
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = nonGuardianId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        await db.SaveChangesAsync();

        var handler = new UpdateMemberPermissionsCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => handler.Handle(new UpdateMemberPermissionsCommand(nonGuardianId, familyId, memberRowId, PermissionLevel.NotificationOnly)));
    }

    public void Dispose() => _factory.Dispose();
}

public class RemoveMemberCommandLastGuardianGuardTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_RemovingTheOnlyGuardian_IsRejected()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();

        db.Families.Add(new Family { Id = familyId, Name = "Solo Guardian Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        var guardianRow = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = guardianId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };
        db.FamilyMembers.Add(guardianRow);
        await db.SaveChangesAsync();

        var handler = new RemoveMemberCommandHandler(db, new FamilyAuthorizationService(db));

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => handler.Handle(new RemoveMemberCommand(guardianId, familyId, guardianRow.Id)));

        Assert.True(db.FamilyMembers.Single(m => m.Id == guardianRow.Id).IsActive);
    }

    public void Dispose() => _factory.Dispose();
}
