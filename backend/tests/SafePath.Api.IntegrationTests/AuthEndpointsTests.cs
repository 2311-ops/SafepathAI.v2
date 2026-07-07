using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using SafePath.Application.Common.Models;

namespace SafePath.Api.IntegrationTests;

public class AuthEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public AuthEndpointsTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task Register_ReturnsOkWithTokens_ThenLogin_ReturnsOk()
    {
        var client = _factory.CreateClient();
        var email = $"itest-{Guid.NewGuid():N}@example.com";

        var registerResponse = await client.PostAsJsonAsync("/auth/register", new
        {
            email,
            password = "CorrectHorseBattery1",
            fullName = "Integration Test",
            role = "Guardian",
        });

        Assert.Equal(HttpStatusCode.OK, registerResponse.StatusCode);
        var registerBody = await registerResponse.Content.ReadFromJsonAsync<AuthResult>();
        Assert.NotNull(registerBody);
        Assert.True(registerBody!.Succeeded);
        Assert.False(string.IsNullOrWhiteSpace(registerBody.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(registerBody.RefreshToken));

        var loginResponse = await client.PostAsJsonAsync("/auth/login", new
        {
            email,
            password = "CorrectHorseBattery1",
        });

        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
    }

    [Fact]
    public async Task Login_WrongPassword_ReturnsUnauthorized()
    {
        var client = _factory.CreateClient();
        var email = $"itest-{Guid.NewGuid():N}@example.com";

        await client.PostAsJsonAsync("/auth/register", new
        {
            email,
            password = "CorrectHorseBattery1",
            fullName = "Integration Test",
            role = "Member",
        });

        var loginResponse = await client.PostAsJsonAsync("/auth/login", new
        {
            email,
            password = "wrong-password",
        });

        Assert.Equal(HttpStatusCode.Unauthorized, loginResponse.StatusCode);
    }
}
