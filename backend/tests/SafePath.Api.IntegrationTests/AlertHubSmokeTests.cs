using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Sos;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

namespace SafePath.Api.IntegrationTests;

/// <summary>
/// Proves AlertHub's own trust boundary: a family member connects and joins a group namespace
/// distinct from LocationHub's, a non-member/unauthenticated caller is refused, mirroring
/// LocationHubSmokeTests' fixture and transport conventions.
/// </summary>
[Collection("AlertHub smoke")]
public class AlertHubSmokeTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public AlertHubSmokeTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task AlertHub_RejectsUserOutsideRequestedFamily()
    {
        var familyA = await SeedFamily();
        var familyB = await SeedFamily();

        await using var connection = CreateConnection(familyA.FamilyId, familyB.MemberId);
        var closed = new TaskCompletionSource<Exception?>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        connection.Closed += exception =>
        {
            closed.TrySetResult(exception);
            return Task.CompletedTask;
        };

        await connection.StartAsync();

        await WaitFor(closed.Task);
        Assert.Equal(HubConnectionState.Disconnected, connection.State);
    }

    [Fact]
    public async Task AlertHub_RejectsUnauthenticatedConnection()
    {
        var family = await SeedFamily();

        var connection = new HubConnectionBuilder()
            .WithUrl(new Uri(_factory.Server.BaseAddress, $"/hubs/alert?familyId={family.FamilyId}"), options =>
            {
                options.Transports = HttpTransportType.LongPolling;
                options.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
            })
            .Build();

        try
        {
            await Assert.ThrowsAnyAsync<Exception>(() => connection.StartAsync());
        }
        finally
        {
            await connection.DisposeAsync();
        }
    }

    [Fact]
    public async Task AlertHub_AcceptsFamilyMemberAndJoinsAlertGroup()
    {
        var family = await SeedFamily();

        await using var connection = CreateConnection(family.FamilyId, family.MemberId);

        await connection.StartAsync();

        Assert.Equal(HubConnectionState.Connected, connection.State);
    }

    /// <summary>
    /// Exercises 03-08's live-location window end-to-end: a triggered SOS session's guardian is
    /// connected to AlertHub, the sender reports a position through the real HTTP endpoint, and
    /// the guardian's hub connection receives the LiveLocationWindowUpdate invocation carrying
    /// that position.
    /// </summary>
    [Fact]
    public async Task AlertHub_DeliversLiveLocationUpdateToAConnectedRecipient()
    {
        var family = await SeedFamily();

        await using var connection = CreateConnection(family.FamilyId, family.GuardianId);
        var received = new TaskCompletionSource<SosLocationUpdateDto>(
            TaskCreationOptions.RunContinuationsAsynchronously);
        connection.On<SosLocationUpdateDto>("LiveLocationWindowUpdate", update => received.TrySetResult(update));
        await connection.StartAsync();

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add(TestAuthHandler.UserIdHeader, family.MemberId.ToString());
        var sosSessionId = Guid.NewGuid();

        var triggerResponse = await client.PostAsJsonAsync("/sos/trigger", new
        {
            SosSessionId = sosSessionId,
            FamilyId = family.FamilyId,
            Latitude = (double?)null,
            Longitude = (double?)null,
            AccuracyMeters = (double?)null,
            TriggeredAtUtc = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.OK, triggerResponse.StatusCode);

        var locationResponse = await client.PostAsJsonAsync($"/sos/{sosSessionId}/location", new
        {
            Latitude = 30.0444,
            Longitude = 31.2357,
            AccuracyMeters = (double?)5.0,
            RecordedAtUtc = DateTime.UtcNow,
        });
        Assert.Equal(HttpStatusCode.OK, locationResponse.StatusCode);

        var update = await WaitFor(received.Task);
        Assert.Equal(sosSessionId, update.SosSessionId);
        Assert.Equal(30.0444, update.Latitude);
        Assert.Equal(31.2357, update.Longitude);
    }

    [Fact]
    public void AlertHub_UsesGroupNameDistinctFromLocationHub()
    {
        var familyId = Guid.NewGuid();

        var alertGroup = AlertHub.FamilyGroupName(familyId);
        var locationGroup = LocationHub.FamilyGroupName(familyId);

        Assert.NotEqual(alertGroup, locationGroup);
    }

    private HubConnection CreateConnection(Guid familyId, Guid userId) =>
        new HubConnectionBuilder()
            .WithUrl(new Uri(_factory.Server.BaseAddress, $"/hubs/alert?familyId={familyId}"), options =>
            {
                options.Transports = HttpTransportType.LongPolling;
                options.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler();
                options.Headers.Add(TestAuthHandler.UserIdHeader, userId.ToString());
            })
            .Build();

    private async Task<SeededFamily> SeedFamily()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        var familyId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var memberId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        // Users rows are required so TriggerSosCommandHandler's recipient-resolution join (and
        // the SosDeliveryAttempts.RecipientUserId foreign key it writes) succeed for the
        // live-location test below, which drives a real /sos/trigger call through this seed.
        db.Users.AddRange(
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = now },
            new User { Id = memberId, Email = $"member-{memberId}@example.com", FullName = "Member", Role = Role.Member, CreatedAt = now });
        db.Families.Add(new Family
        {
            Id = familyId,
            Name = "AlertHub Smoke Family",
            CreatedByUserId = guardianId,
            CreatedAt = now,
        });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = guardianId,
                Role = Role.Guardian,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = now,
                IsActive = true,
            },
            new FamilyMember
            {
                Id = Guid.NewGuid(),
                FamilyId = familyId,
                UserId = memberId,
                Role = Role.Member,
                Permissions = PermissionLevel.ViewOnly,
                JoinedAt = now,
                IsActive = true,
            });
        await db.SaveChangesAsync();

        return new SeededFamily(familyId, guardianId, memberId);
    }

    private static async Task<T> WaitFor<T>(Task<T> task)
    {
        var completed = await Task.WhenAny(task, Task.Delay(TimeSpan.FromSeconds(10)));
        Assert.Same(task, completed);
        return await task;
    }

    private sealed record SeededFamily(Guid FamilyId, Guid GuardianId, Guid MemberId);
}

[CollectionDefinition("AlertHub smoke", DisableParallelization = true)]
public sealed class AlertHubSmokeCollection
{
}
