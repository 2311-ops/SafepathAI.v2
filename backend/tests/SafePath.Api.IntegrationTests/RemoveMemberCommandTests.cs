using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

/// <summary>
/// Proves server-side family-scoped authorization is enforced by the real HTTP pipeline, not
/// just hidden in the UI (IDOR prevention, locked decision D5): a removed member is denied on a
/// subsequent authenticated request, and a Guardian of one family cannot remove a member of a
/// different family.
/// </summary>
public class RemoveMemberCommandTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public RemoveMemberCommandTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    private async Task<(Guid FamilyId, Guid GuardianId, Guid MemberUserId, Guid MemberRowId)> SeedFamily()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberUserId = Guid.NewGuid();

        db.Families.Add(new Family { Id = familyId, Name = "Test Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
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
            UserId = memberUserId,
            Role = Role.Member,
            Permissions = PermissionLevel.ViewOnly,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };
        db.FamilyMembers.Add(memberRow);
        await db.SaveChangesAsync();

        return (familyId, guardianId, memberUserId, memberRow.Id);
    }

    private HttpClient CreateClientAs(Guid userId)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, userId.ToString());
        return client;
    }

    [Fact]
    public async Task RemoveMember_ByGuardian_SoftRemovesAndDeniesFurtherAccess()
    {
        var (familyId, guardianId, memberUserId, memberRowId) = await SeedFamily();
        var guardianClient = CreateClientAs(guardianId);

        var response = await guardianClient.DeleteAsync($"/families/{familyId}/members/{memberRowId}");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var removed = db.FamilyMembers.Single(m => m.Id == memberRowId);
            Assert.False(removed.IsActive);
            Assert.NotNull(removed.RemovedAt);
        }

        // The removed member's own authenticated request to a family-scoped endpoint is now
        // denied server-side — proving this is not just a UI-hidden button (IDOR prevention).
        var removedMemberClient = CreateClientAs(memberUserId);
        var listResponse = await removedMemberClient.GetAsync($"/families/{familyId}/members");
        Assert.Equal(HttpStatusCode.Forbidden, listResponse.StatusCode);
    }

    [Fact]
    public async Task RemoveMember_CrossFamily_IsDenied()
    {
        var (familyAId, guardianAId, _, _) = await SeedFamily();
        var (_, _, _, memberBRowId) = await SeedFamily();

        var guardianAClient = CreateClientAs(guardianAId);

        var response = await guardianAClient.DeleteAsync($"/families/{familyAId}/members/{memberBRowId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var stillActive = db.FamilyMembers.Single(m => m.Id == memberBRowId);
        Assert.True(stillActive.IsActive);
    }

    [Fact]
    public async Task UpdatePermissions_ByGuardian_Returns200AndPersists()
    {
        var (familyId, guardianId, _, memberRowId) = await SeedFamily();
        var guardianClient = CreateClientAs(guardianId);

        var response = await guardianClient.PatchAsJsonAsync(
            $"/families/{familyId}/members/{memberRowId}/permissions",
            new { Permissions = PermissionLevel.NotificationOnly });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(PermissionLevel.NotificationOnly, db.FamilyMembers.Single(m => m.Id == memberRowId).Permissions);
    }
}

/// <summary>Fabricates an authenticated ClaimsPrincipal from a test-only header, replacing the
/// real Supabase JwtBearer scheme for integration tests that need an authenticated caller.</summary>
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    public const string UserIdHeader = "X-Test-User-Id";

    public TestAuthHandler(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(UserIdHeader, out var values) || !Guid.TryParse(values.FirstOrDefault(), out var userId))
        {
            return Task.FromResult(AuthenticateResult.Fail("Missing or invalid test user id header."));
        }

        var identity = new ClaimsIdentity(new[] { new Claim("sub", userId.ToString()) }, SchemeName);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}

public sealed class FamilyApiFactory : WebApplicationFactory<Program>
{
    private readonly SqliteConnection _connection = new("DataSource=:memory:");

    public FamilyApiFactory()
    {
        _connection.Open();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll(typeof(DbContextOptions<ApplicationDbContext>));
            services.RemoveAll(typeof(DbContextOptions));
            services.RemoveAll(typeof(IDbContextOptionsConfiguration<ApplicationDbContext>));
            services.RemoveAll(typeof(IDbContextOptionsConfiguration<DbContext>));
            services.RemoveAll(typeof(ApplicationDbContext));
            services.AddDbContext<ApplicationDbContext>(options => options.UseSqlite(_connection));

            services.AddAuthentication()
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });

            // PostConfigure runs after the real Program.cs AddAuthentication(JwtBearer) call,
            // so this reliably wins and makes [Authorize] resolve to TestAuthHandler.
            services.PostConfigure<AuthenticationOptions>(options =>
            {
                options.DefaultAuthenticateScheme = TestAuthHandler.SchemeName;
                options.DefaultChallengeScheme = TestAuthHandler.SchemeName;
                options.DefaultForbidScheme = TestAuthHandler.SchemeName;
                options.DefaultScheme = TestAuthHandler.SchemeName;
            });

            using var scope = services.BuildServiceProvider().CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            dbContext.Database.EnsureCreated();
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing)
        {
            _connection.Dispose();
        }
    }
}
