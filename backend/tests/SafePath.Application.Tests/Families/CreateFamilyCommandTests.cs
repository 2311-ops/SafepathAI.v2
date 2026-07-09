using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class CreateFamilyCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_CreatesFamilyAndGuardianMembership()
    {
        await using var db = _factory.CreateContext();
        var handler = new CreateFamilyCommandHandler(db);
        var userId = Guid.NewGuid();

        var familyId = await handler.Handle(new CreateFamilyCommand(userId, "The Hassans"));

        var family = db.Families.Single(f => f.Id == familyId);
        Assert.Equal("The Hassans", family.Name);
        Assert.Equal(userId, family.CreatedByUserId);

        var membership = db.FamilyMembers.Single(m => m.FamilyId == familyId);
        Assert.Equal(userId, membership.UserId);
        Assert.Equal(Role.Guardian, membership.Role);
        Assert.Equal(PermissionLevel.FullLocation, membership.Permissions);
        Assert.True(membership.IsActive);
    }

    [Fact]
    public async Task Handle_RejectsBlankName()
    {
        await using var db = _factory.CreateContext();
        var handler = new CreateFamilyCommandHandler(db);

        await Assert.ThrowsAsync<ArgumentException>(
            () => handler.Handle(new CreateFamilyCommand(Guid.NewGuid(), "  ")));
    }

    public void Dispose() => _factory.Dispose();
}

public class FamilyAuthorizationServiceTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task RequireMembership_ReturnsActiveMemberRow()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new()
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        await db.SaveChangesAsync();

        var service = new FamilyAuthorizationService(db);
        var member = await service.RequireMembership(userId, familyId);

        Assert.Equal(userId, member.UserId);
    }

    [Fact]
    public async Task RequireMembership_DeniesUserWithNoFamilyMemberRow()
    {
        await using var db = _factory.CreateContext();
        var service = new FamilyAuthorizationService(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => service.RequireMembership(Guid.NewGuid(), Guid.NewGuid()));
    }

    [Fact]
    public async Task RequireRole_DeniesNonGuardianMember()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var userId = Guid.NewGuid();
        db.Families.Add(new Family { Id = familyId, Name = "Seed Family", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new()
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        await db.SaveChangesAsync();

        var service = new FamilyAuthorizationService(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(
            () => service.RequireRole(userId, familyId, Role.Guardian));
    }

    public void Dispose() => _factory.Dispose();
}
