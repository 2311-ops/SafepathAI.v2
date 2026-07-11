using SafePath.Application.Families;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using Xunit;

namespace SafePath.Application.Tests.Families;

public class GetMeQueryTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Handle_ReturnsRoleAndProfileFromUsersTable()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(new User
        {
            Id = userId,
            Email = "guardian@safepath.test",
            FullName = "Nadia Guardian",
            Role = Role.Guardian,
            CreatedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var handler = new GetMeQueryHandler(db);
        var result = await handler.Handle(new GetMeQuery(userId));

        Assert.Equal(userId, result.UserId);
        Assert.Equal(Role.Guardian, result.Role);
        Assert.Equal("guardian@safepath.test", result.Email);
        Assert.Equal("Nadia Guardian", result.FullName);
    }

    [Fact]
    public async Task Handle_MissingUserRow_ReturnsNullProfileWithoutThrowing()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        var handler = new GetMeQueryHandler(db);

        var result = await handler.Handle(new GetMeQuery(userId));

        Assert.Equal(userId, result.UserId);
        Assert.Null(result.Role);
        Assert.Null(result.Email);
        Assert.Null(result.FullName);
    }

    [Fact]
    public async Task Handle_UserWithoutSelectedRole_ReturnsNullRole()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(new User
        {
            Id = userId,
            Email = "oauth@safepath.test",
            FullName = "OAuth User",
            Role = null,
            CreatedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var handler = new GetMeQueryHandler(db);
        var result = await handler.Handle(new GetMeQuery(userId));

        Assert.Equal(userId, result.UserId);
        Assert.Null(result.Role);
    }

    [Fact]
    public async Task UpdateMyRole_SetsRoleForOAuthUser()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(new User
        {
            Id = userId,
            Email = "oauth@safepath.test",
            FullName = "OAuth User",
            Role = null,
            CreatedAt = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        var handler = new UpdateMyRoleCommandHandler(db);
        var result = await handler.Handle(
            new UpdateMyRoleCommand(userId, Role.Caregiver, null, null));

        Assert.Equal(Role.Caregiver, result.Role);
        Assert.Equal(Role.Caregiver, db.Users.Single(u => u.Id == userId).Role);
    }

    public void Dispose() => _factory.Dispose();
}
