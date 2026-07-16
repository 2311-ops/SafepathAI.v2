using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

namespace SafePath.Api.IntegrationTests;

[Collection("LocationHub smoke")]
public class LocationHubSmokeTests : IClassFixture<FamilyApiFactory>
{
    private readonly FamilyApiFactory _factory;

    public LocationHubSmokeTests(FamilyApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task LocationHub_RejectsUserOutsideRequestedFamily()
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

    private HubConnection CreateConnection(Guid familyId, Guid userId) =>
        new HubConnectionBuilder()
            .WithUrl(new Uri(_factory.Server.BaseAddress, $"/hubs/location?familyId={familyId}"), options =>
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

        db.Families.Add(new Family
        {
            Id = familyId,
            Name = "SignalR Smoke Family",
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

[CollectionDefinition("LocationHub smoke", DisableParallelization = true)]
public sealed class LocationHubSmokeCollection
{
}
