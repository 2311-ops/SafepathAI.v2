using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Api.IntegrationTests;

public sealed class NotificationsControllerTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public NotificationsControllerTests(FamilyApiFactory factory) => _factory = factory;

    [Fact]
    public async Task Feed_IsRecipientScopedAndReadIsOwnerOnlyAndIdempotent()
    {
        var fixture = await SeedAsync();
        var owner = CreateClientAs(fixture.OwnerUserId);
        var other = CreateClientAs(fixture.OtherUserId);

        var feed = await owner.GetAsync("/notifications");
        Assert.Equal(HttpStatusCode.OK, feed.StatusCode);
        using var body = JsonDocument.Parse(await feed.Content.ReadAsStringAsync());
        var item = Assert.Single(body.RootElement.EnumerateArray());
        Assert.Equal(fixture.OwnerFeedItemId, item.GetProperty("id").GetGuid());
        Assert.Equal(fixture.MemberUserId, item.GetProperty("memberUserId").GetGuid());
        Assert.Equal("Member", item.GetProperty("memberDisplayName").GetString());
        Assert.Equal(fixture.SafeZoneId, item.GetProperty("safeZoneId").GetGuid());
        Assert.Equal("Home", item.GetProperty("zoneName").GetString());
        Assert.Equal("Enter", item.GetProperty("transition").GetString());
        Assert.Equal(fixture.OccurredAtUtc, item.GetProperty("occurredAtUtc").GetDateTime());
        Assert.False(item.GetProperty("isRead").GetBoolean());
        Assert.False(item.TryGetProperty("latitude", out _));
        Assert.False(item.TryGetProperty("longitude", out _));
        Assert.False(item.TryGetProperty("deliveryConfidence", out _));

        Assert.Equal(HttpStatusCode.NotFound, (await other.PostAsync($"/notifications/{fixture.OwnerFeedItemId}/read", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.PostAsync($"/notifications/{fixture.OwnerFeedItemId}/read", null)).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await owner.PostAsync($"/notifications/{fixture.OwnerFeedItemId}/read", null)).StatusCode);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.NotNull(db.GeofenceFeedItems.Single(item => item.Id == fixture.OwnerFeedItemId).ReadAtUtc);
        Assert.Single(db.GeofenceFeedItems.Where(item => item.Id == fixture.OtherFeedItemId));
    }

    private HttpClient CreateClientAs(Guid userId)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, userId.ToString());
        return client;
    }

    private async Task<Fixture> SeedAsync()
    {
        var now = DateTime.UtcNow;
        var ownerUserId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var memberUserId = Guid.NewGuid();
        var familyId = Guid.NewGuid();
        var activityId = Guid.NewGuid();
        var safeZoneId = Guid.NewGuid();
        var ownerFeedItemId = Guid.NewGuid();
        var otherFeedItemId = Guid.NewGuid();
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        db.Users.AddRange(
            new User { Id = ownerUserId, Email = $"owner-{ownerUserId:N}@example.com", FullName = "Owner", Role = Role.Guardian, CreatedAt = now },
            new User { Id = otherUserId, Email = $"other-{otherUserId:N}@example.com", FullName = "Other", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberUserId, Email = $"member-{memberUserId:N}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = now });
        db.Families.Add(new Family
        {
            Id = familyId,
            Name = "Test family",
            CreatedByUserId = ownerUserId,
            CreatedAt = now,
        });
        db.SafeZones.Add(new SafeZone
        {
            Id = safeZoneId,
            FamilyId = familyId,
            AssignedMemberUserId = memberUserId,
            CreatedByUserId = ownerUserId,
            Category = SafeZoneCategory.Home,
            Latitude = 30.0444,
            Longitude = 31.2357,
            RadiusMeters = 250,
            Sensitivity = SafeZoneSensitivity.Balanced,
            CreatedAtUtc = now,
        });
        db.GeofenceActivities.Add(new GeofenceActivity
        {
            Id = activityId,
            SafeZoneId = safeZoneId,
            SafeZoneDisplayName = "Home",
            MemberUserId = memberUserId,
            Transition = GeofenceTransition.Enter,
            OccurredAtUtc = now,
            RecordedAtUtc = now,
            RetainUntilUtc = now.AddDays(7),
        });
        db.GeofenceFeedItems.AddRange(
            new GeofenceFeedItem { Id = ownerFeedItemId, ActivityId = activityId, RecipientUserId = ownerUserId, CreatedAtUtc = now, ExpiresAtUtc = now.AddDays(7) },
            new GeofenceFeedItem { Id = otherFeedItemId, ActivityId = activityId, RecipientUserId = otherUserId, CreatedAtUtc = now, ExpiresAtUtc = now.AddDays(7) });
        await db.SaveChangesAsync();
        return new Fixture(ownerUserId, otherUserId, memberUserId, safeZoneId, ownerFeedItemId, otherFeedItemId, now);
    }

    private sealed record Fixture(Guid OwnerUserId, Guid OtherUserId, Guid MemberUserId, Guid SafeZoneId, Guid OwnerFeedItemId, Guid OtherFeedItemId, DateTime OccurredAtUtc);
}
