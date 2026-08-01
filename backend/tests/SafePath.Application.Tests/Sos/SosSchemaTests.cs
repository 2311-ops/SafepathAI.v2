using Microsoft.EntityFrameworkCore;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using Xunit;

namespace SafePath.Application.Tests.Sos;

public class SosSchemaTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task CreateContext_MaterialisesAllSosTables()
    {
        await using var db = _factory.CreateContext();

        var familyId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        db.SosSessions.Add(new SosSession
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            TriggeredByUserId = userId,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = Guid.NewGuid(),
            Channel = AlertChannel.SignalR,
        });
        db.EmergencyContacts.Add(new EmergencyContact
        {
            Id = Guid.NewGuid(),
            OwnerUserId = userId,
            DisplayName = "Mom",
            PhoneNumberE164 = "+15551234567",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        db.UserDeviceTokens.Add(new UserDeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Token = "token-1",
            Platform = DevicePlatform.Android,
            CreatedAtUtc = DateTime.UtcNow,
            LastSeenAtUtc = DateTime.UtcNow,
        });

        var saved = await db.SaveChangesAsync();

        Assert.True(saved >= 4);
    }

    [Fact]
    public void SosSession_DefaultsToVisibleKind()
    {
        var session = new SosSession();

        Assert.Equal(SosKind.Visible, session.Kind);
    }

    [Fact]
    public async Task SosSession_RejectsDuplicateId()
    {
        await using var db = _factory.CreateContext();
        var duplicateId = Guid.NewGuid();
        var familyId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        db.SosSessions.Add(new SosSession
        {
            Id = duplicateId,
            FamilyId = familyId,
            TriggeredByUserId = userId,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();

        await using var db2 = _factory.CreateContext();
        db2.SosSessions.Add(new SosSession
        {
            Id = duplicateId,
            FamilyId = familyId,
            TriggeredByUserId = userId,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });

        await Assert.ThrowsAnyAsync<Exception>(() => db2.SaveChangesAsync());
    }

    [Fact]
    public async Task UserDeviceToken_AllowsMultipleTokensPerUser()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();

        db.UserDeviceTokens.AddRange(
            new UserDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = "token-a",
                Platform = DevicePlatform.Android,
                CreatedAtUtc = DateTime.UtcNow,
                LastSeenAtUtc = DateTime.UtcNow,
            },
            new UserDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = "token-b",
                Platform = DevicePlatform.Ios,
                CreatedAtUtc = DateTime.UtcNow,
                LastSeenAtUtc = DateTime.UtcNow,
            });

        await db.SaveChangesAsync();

        Assert.Equal(2, db.UserDeviceTokens.Count(t => t.UserId == userId));
    }

    public void Dispose() => _factory.Dispose();
}
