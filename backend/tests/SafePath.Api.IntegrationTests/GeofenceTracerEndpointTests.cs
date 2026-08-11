using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

/// <summary>
/// Exercises the smallest production-shaped geofence path: Guardian configuration, assigned
/// member registration acknowledgement, then native candidate ingestion.  The tests use the
/// real HTTP host so current-user binding and family authorization cannot be bypassed.
/// </summary>
public sealed class GeofenceTracerEndpointTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public GeofenceTracerEndpointTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GuardianToAssignedMemberRoundTrip_AcceptsCandidateAndMakesReplayIdempotent()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);

        var create = await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", new
        {
            Category = "Home",
            CustomName = (string?)null,
            Latitude = 30.0444,
            Longitude = 31.2357,
            RadiusMeters = 150.0,
            AssignedMemberUserId = family.MemberUserId,
            Sensitivity = "Balanced",
            RecipientUserIds = new[] { family.GuardianUserId },
            NotifyAssignedMember = true,
        });

        Assert.Equal(HttpStatusCode.Created, create.StatusCode);
        using var created = JsonDocument.Parse(await create.Content.ReadAsStringAsync());
        var zoneId = created.RootElement.GetProperty("zoneId").GetGuid();
        var generation = created.RootElement.GetProperty("registrationGeneration").GetInt32();

        var member = CreateClientAs(family.MemberUserId);
        var registration = await member.GetAsync("/geofences/registration");
        Assert.Equal(HttpStatusCode.OK, registration.StatusCode);
        using var registrationBody = JsonDocument.Parse(await registration.Content.ReadAsStringAsync());
        Assert.Equal(zoneId, registrationBody.RootElement.GetProperty("zoneId").GetGuid());
        Assert.Equal(generation, registrationBody.RootElement.GetProperty("generation").GetInt32());

        var acknowledgement = await member.PostAsync(
            $"/geofences/{zoneId}/registrations/{generation}/acknowledgements",
            content: null);
        Assert.Equal(HttpStatusCode.NoContent, acknowledgement.StatusCode);

        var eventId = Guid.NewGuid();
        var candidate = new
        {
            EventId = eventId,
            ZoneId = zoneId,
            RegistrationGeneration = generation,
            Transition = "Enter",
            OccurredAtUtc = DateTime.UtcNow,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 8.0,
        };

        var accepted = await member.PostAsJsonAsync("/geofences/candidates", candidate);
        Assert.Equal(HttpStatusCode.Accepted, accepted.StatusCode);
        Assert.Equal("Accepted", (await accepted.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("outcome").GetString());

        var duplicate = await member.PostAsJsonAsync("/geofences/candidates", candidate);
        Assert.Equal(HttpStatusCode.OK, duplicate.StatusCode);
        Assert.Equal("Duplicate", (await duplicate.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("outcome").GetString());

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Single(db.GeofenceCandidates.Where(c => c.EventId == eventId));
    }

    [Fact]
    public async Task ZoneCreationAndMemberRegistration_RejectUnauthenticatedAndCrossFamilyCallers()
    {
        var family = await SeedFamilyAsync();
        var unauthenticated = _factory.CreateClient();

        var unauthenticatedResponse = await unauthenticated.GetAsync("/geofences/registration");
        Assert.Equal(HttpStatusCode.Unauthorized, unauthenticatedResponse.StatusCode);

        var nonGuardian = CreateClientAs(family.MemberUserId);
        var nonGuardianCreate = await nonGuardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", new
        {
            Category = "School",
            Latitude = 30.0,
            Longitude = 31.0,
            RadiusMeters = 100.0,
            AssignedMemberUserId = family.MemberUserId,
            Sensitivity = "Balanced",
            RecipientUserIds = new[] { family.GuardianUserId },
            NotifyAssignedMember = false,
        });
        Assert.Equal(HttpStatusCode.Forbidden, nonGuardianCreate.StatusCode);

        var outsider = CreateClientAs(Guid.NewGuid());
        var outsiderRegistration = await outsider.GetAsync("/geofences/registration");
        Assert.Equal(HttpStatusCode.Forbidden, outsiderRegistration.StatusCode);
    }

    [Fact]
    public async Task Candidate_RejectsWrongMemberStaleGenerationAndInactiveRegistration()
    {
        var family = await SeedFamilyAsync();
        var guardian = CreateClientAs(family.GuardianUserId);
        var create = await guardian.PostAsJsonAsync($"/families/{family.FamilyId}/geofences", new
        {
            Category = "Home", Latitude = 30.0444, Longitude = 31.2357, RadiusMeters = 150.0,
            AssignedMemberUserId = family.MemberUserId, Sensitivity = "Balanced",
            RecipientUserIds = new[] { family.GuardianUserId }, NotifyAssignedMember = true,
        });
        using var created = JsonDocument.Parse(await create.Content.ReadAsStringAsync());
        var zoneId = created.RootElement.GetProperty("zoneId").GetGuid();

        var candidate = new { EventId = Guid.NewGuid(), ZoneId = zoneId, RegistrationGeneration = 1, Transition = "Exit", OccurredAtUtc = DateTime.UtcNow, Latitude = 30.0444, Longitude = 31.2357, AccuracyMeters = 5.0 };
        var wrongMember = await guardian.PostAsJsonAsync("/geofences/candidates", candidate);
        Assert.Equal(HttpStatusCode.Forbidden, wrongMember.StatusCode);

        var member = CreateClientAs(family.MemberUserId);
        var stale = await member.PostAsJsonAsync("/geofences/candidates", new { candidate.EventId, candidate.ZoneId, RegistrationGeneration = 2, candidate.Transition, candidate.OccurredAtUtc, candidate.Latitude, candidate.Longitude, candidate.AccuracyMeters });
        Assert.Equal(HttpStatusCode.BadRequest, stale.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.FamilyMembers.Single(row => row.FamilyId == family.FamilyId && row.UserId == family.MemberUserId).IsActive = false;
            await db.SaveChangesAsync();
        }
        var inactive = await member.PostAsJsonAsync("/geofences/candidates", candidate);
        Assert.Equal(HttpStatusCode.Forbidden, inactive.StatusCode);
    }

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
        db.Families.Add(new Family { Id = familyId, Name = "Tracer Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = memberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        await db.SaveChangesAsync();
        return (familyId, guardianId, memberId);
    }
}
