using System.Net;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

public class MeEndpointTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public MeEndpointTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Me_WithoutToken_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/me");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Me_WithMissingServiceRoleKey_ReturnsProfileInsteadOfStorageConfigurationError()
    {
        var userId = Guid.NewGuid();
        using (var scope = _factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.Users.Add(new User
            {
                Id = userId,
                Email = "member@safepath.test",
                FullName = "Member Test",
                Role = Role.Caregiver,
                CreatedAt = DateTime.UtcNow,
            });
            await dbContext.SaveChangesAsync();
        }

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, userId.ToString());

        var response = await client.GetAsync("/me");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}
