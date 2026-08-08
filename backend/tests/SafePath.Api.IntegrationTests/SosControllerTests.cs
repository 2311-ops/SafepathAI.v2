using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Sos;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

/// <summary>
/// Proves the full HTTP pipeline for the SOS trigger/status endpoints: caller identity comes
/// only from the authenticated request (never the body), non-members are denied server-side,
/// and the response shape is per-recipient/per-channel — never a single boolean (D-09).
/// </summary>
public class SosControllerTests : IClassFixture<FamilyApiFactory>
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() },
    };

    private readonly FamilyApiFactory _factory;

    public SosControllerTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    private async Task<(Guid FamilyId, Guid CallerId, Guid GuardianId)> SeedFamily()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Test Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = callerId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });

        await db.SaveChangesAsync();
        return (familyId, callerId, guardianId);
    }

    private HttpClient CreateClientAs(Guid userId)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, userId.ToString());
        return client;
    }

    [Fact]
    public async Task Trigger_ReturnsPerChannelDeliveryState()
    {
        var (familyId, callerId, _) = await SeedFamily();
        var client = CreateClientAs(callerId);

        var response = await client.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = Guid.NewGuid(),
            FamilyId = familyId,
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = 10.0,
            TriggeredAtUtc = DateTime.UtcNow,
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<TriggerSosResult>(JsonOptions);
        Assert.NotNull(body);
        var recipient = Assert.Single(body!.Session.Recipients);
        // 03-06: every Guardian recipient now also gets an Fcm channel row alongside SignalR (D-06).
        Assert.Equal(2, recipient.Channels.Count);
        Assert.Contains(recipient.Channels, c => c.Channel == AlertChannel.SignalR && c.Status == SosDeliveryStatus.NotAttempted);
        Assert.Contains(recipient.Channels, c => c.Channel == AlertChannel.Fcm && c.Status == SosDeliveryStatus.NotAttempted);
    }

    [Fact]
    public async Task Trigger_ReturnsUnauthorizedWithoutAuthenticatedUser()
    {
        var (familyId, _, _) = await SeedFamily();
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = Guid.NewGuid(),
            FamilyId = familyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Trigger_ReturnsForbiddenForNonMemberFamily()
    {
        var (familyId, _, _) = await SeedFamily();
        var outsiderId = Guid.NewGuid();
        var client = CreateClientAs(outsiderId);

        var response = await client.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = Guid.NewGuid(),
            FamilyId = familyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Trigger_ReturnsForbiddenWhenReplayingAnotherFamilysSessionId()
    {
        var (familyId, callerId, _) = await SeedFamily();
        var sosSessionId = Guid.NewGuid();
        var owningClient = CreateClientAs(callerId);

        var triggerResponse = await owningClient.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = sosSessionId,
            FamilyId = familyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.OK, triggerResponse.StatusCode);

        var outsiderId = Guid.NewGuid();
        var outsiderClient = CreateClientAs(outsiderId);

        var replayResponse = await outsiderClient.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = sosSessionId,
            FamilyId = familyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });

        Assert.Equal(HttpStatusCode.Forbidden, replayResponse.StatusCode);
    }

    [Fact]
    public async Task Get_ReturnsCurrentSessionStatus()
    {
        var (familyId, callerId, _) = await SeedFamily();
        var client = CreateClientAs(callerId);
        var sosSessionId = Guid.NewGuid();

        var triggerResponse = await client.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = sosSessionId,
            FamilyId = familyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.OK, triggerResponse.StatusCode);

        var getResponse = await client.GetAsync($"/sos/{sosSessionId}");

        Assert.Equal(HttpStatusCode.OK, getResponse.StatusCode);
        var dto = await getResponse.Content.ReadFromJsonAsync<SosSessionDto>(JsonOptions);
        Assert.NotNull(dto);
        Assert.Equal(sosSessionId, dto!.SosSessionId);
    }
}
