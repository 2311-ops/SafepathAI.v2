using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

public sealed class GeofencesControllerTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;
    public GeofencesControllerTests(FamilyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Management_RejectsMemberAndCrossFamilyGuardian()
    {
        var family = await SeedFamilyAsync();
        var member = CreateClientAs(family.MemberUserId);
        var memberList = await member.GetAsync($"/families/{family.FamilyId}/geofences");
        Assert.Equal(HttpStatusCode.Forbidden, memberList.StatusCode);

        var other = await SeedFamilyAsync();
        var otherGuardian = CreateClientAs(other.GuardianUserId);
        var crossFamilyList = await otherGuardian.GetAsync($"/families/{family.FamilyId}/geofences");
        Assert.Equal(HttpStatusCode.Forbidden, crossFamilyList.StatusCode);
    }

    [Fact]
    public async Task Create_EnforcesMalformedAndTwentyZoneContracts()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);
        var malformed = await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 99));
        Assert.Equal(HttpStatusCode.BadRequest, malformed.StatusCode);

        for (var index = 0; index < 20; index++)
            Assert.Equal(HttpStatusCode.Created, (await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 100 + index))).StatusCode);

        var capped = await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 150));
        Assert.Equal(HttpStatusCode.Conflict, capped.StatusCode);
    }

    [Fact]
    public async Task MemberRegistration_IsScopedAndRejectsStaleAcknowledgement()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);
        using var created = JsonDocument.Parse(await (await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 100))).Content.ReadAsStringAsync());
        var zoneId = created.RootElement.GetProperty("zoneId").GetGuid();

        var update = await guardian.PutAsJsonAsync($"/families/{family.FamilyId}/geofences/{zoneId}", Request(family.MemberUserId, 120));
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        using var updated = JsonDocument.Parse(await update.Content.ReadAsStringAsync());
        var currentGeneration = updated.RootElement.GetProperty("registrationGeneration").GetInt32();

        var member = CreateClientAs(family.MemberUserId);
        var registrations = await member.GetAsync("/geofences/registrations");
        Assert.Equal(HttpStatusCode.OK, registrations.StatusCode);
        using var registrationBody = JsonDocument.Parse(await registrations.Content.ReadAsStringAsync());
        Assert.Single(registrationBody.RootElement.EnumerateArray());
        var stale = await member.PostAsync($"/geofences/{zoneId}/registrations/{currentGeneration - 1}/acknowledgements/current", null);
        Assert.Equal(HttpStatusCode.NotFound, stale.StatusCode);
        var current = await member.PostAsync($"/geofences/{zoneId}/registrations/{currentGeneration}/acknowledgements/current", null);
        Assert.Equal(HttpStatusCode.NoContent, current.StatusCode);
        var staleCandidate = await member.PostAsJsonAsync("/geofences/candidates", new
        {
            EventId = Guid.NewGuid(),
            ZoneId = zoneId,
            RegistrationGeneration = currentGeneration - 1,
            Transition = "Enter",
            OccurredAtUtc = DateTime.UtcNow,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 5.0,
        });
        Assert.Equal(HttpStatusCode.BadRequest, staleCandidate.StatusCode);
    }

    [Fact]
    public async Task Delete_StopsMonitoringWithoutErasingRetainedActivity()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);
        using var created = JsonDocument.Parse(await (await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 100))).Content.ReadAsStringAsync());
        var zoneId = created.RootElement.GetProperty("zoneId").GetGuid();
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.GeofenceActivities.Add(new GeofenceActivity { Id = Guid.NewGuid(), SafeZoneId = zoneId, SafeZoneDisplayName = "Home", MemberUserId = family.MemberUserId, Transition = GeofenceTransition.Enter, OccurredAtUtc = DateTime.UtcNow, RecordedAtUtc = DateTime.UtcNow, RetainUntilUtc = DateTime.UtcNow.AddDays(7) });
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.NoContent, (await guardian.DeleteAsync($"/families/{family.FamilyId}/geofences/{zoneId}")).StatusCode);
        using var verificationScope = _factory.Services.CreateScope();
        var verificationDb = verificationScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.False(verificationDb.SafeZones.Single(zone => zone.Id == zoneId).IsActive);
        Assert.Single(verificationDb.GeofenceActivities.Where(activity => activity.SafeZoneId == zoneId));
    }

    [Fact]
    public async Task Toggle_DisablesAndEnablesZone()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);
        using var created = JsonDocument.Parse(await (await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", Request(family.MemberUserId, 100))).Content.ReadAsStringAsync());
        var zoneId = created.RootElement.GetProperty("zoneId").GetGuid();

        var disabled = await guardian.PostAsync($"/families/{family.FamilyId}/geofences/{zoneId}/disable", null);
        Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        using var disabledBody = JsonDocument.Parse(await disabled.Content.ReadAsStringAsync());
        Assert.False(disabledBody.RootElement.GetProperty("active").GetBoolean());

        var enabled = await guardian.PostAsync($"/families/{family.FamilyId}/geofences/{zoneId}/enable", null);
        Assert.Equal(HttpStatusCode.OK, enabled.StatusCode);
        using var enabledBody = JsonDocument.Parse(await enabled.Content.ReadAsStringAsync());
        Assert.True(enabledBody.RootElement.GetProperty("active").GetBoolean());
        Assert.True(enabledBody.RootElement.GetProperty("needsLocationPermission").GetBoolean());
    }

    private static object Request(Guid assignedMemberUserId, double radius) => new
    {
        Category = "Home",
        Latitude = 30.0444,
        Longitude = 31.2357,
        RadiusMeters = radius,
        AssignedMemberUserId = assignedMemberUserId,
        Sensitivity = "Balanced",
        RecipientUserIds = (Guid[]?)null,
        NotifyAssignedMember = false,
    };

    private HttpClient CreateClientAs(Guid userId)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, userId.ToString());
        return client;
    }

    private async Task<(Guid FamilyId, Guid GuardianUserId, Guid MemberUserId)> SeedFamilyAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = memberId, Email = $"member-{memberId}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Zone Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        await db.SaveChangesAsync();
        return (familyId, guardianId, memberId);
    }
}
