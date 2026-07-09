using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class ListMyFamiliesQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_UserWithOneActiveMembership_ReturnsThatFamily()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var familyId = Guid.NewGuid();

        db.Families.Add(new Family { Id = familyId, Name = "The Hassans", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
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

        var handler = new ListMyFamiliesQueryHandler(db);

        var result = await handler.Handle(new ListMyFamiliesQuery(userId));

        var family = Assert.Single(result);
        Assert.Equal(familyId, family.FamilyId);
        Assert.Equal("The Hassans", family.FamilyName);
        Assert.Equal(Role.Guardian, family.Role);
        Assert.Equal(PermissionLevel.FullLocation, family.Permissions);
    }

    [Fact]
    public async Task Handle_UserWithNoMemberships_ReturnsEmptyList()
    {
        await using var db = _factory.CreateContext();
        var handler = new ListMyFamiliesQueryHandler(db);

        var result = await handler.Handle(new ListMyFamiliesQuery(Guid.NewGuid()));

        Assert.Empty(result);
    }

    [Fact]
    public async Task Handle_RemovedMembership_IsExcluded()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var familyId = Guid.NewGuid();

        db.Families.Add(new Family { Id = familyId, Name = "The Hassans", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = userId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = false,
            RemovedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var handler = new ListMyFamiliesQueryHandler(db);

        var result = await handler.Handle(new ListMyFamiliesQuery(userId));

        Assert.Empty(result);
    }

    [Fact]
    public async Task Handle_UserWithActiveAndHistoricalMembership_ReturnsOnlyActive()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var familyOneId = Guid.NewGuid();
        var familyTwoId = Guid.NewGuid();

        db.Families.Add(new Family { Id = familyOneId, Name = "Family One", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyTwoId, Name = "Family Two", CreatedByUserId = Guid.NewGuid(), CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyOneId,
            UserId = userId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyTwoId,
            UserId = userId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = false,
            RemovedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var handler = new ListMyFamiliesQueryHandler(db);

        var result = await handler.Handle(new ListMyFamiliesQuery(userId));

        var family = Assert.Single(result);
        Assert.Equal(familyOneId, family.FamilyId);
        Assert.Equal(Role.Guardian, family.Role);
    }

    public void Dispose() => _factory.Dispose();
}
