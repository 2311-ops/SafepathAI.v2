using Microsoft.EntityFrameworkCore;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Sos;

public class SosSchemaTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task CreateContext_MaterialisesAllSosTables()
    {
        await using var db = _factory.CreateContext();
        var (familyId, userId) = await SeedFamilyAndUser(db);

        var sessionId = Guid.NewGuid();
        db.SosSessions.Add(new SosSession
        {
            Id = sessionId,
            FamilyId = familyId,
            TriggeredByUserId = userId,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            RecipientUserId = userId,
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
        var (familyId, userId) = await SeedFamilyAndUser(db);
        var duplicateId = Guid.NewGuid();

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

        await Assert.ThrowsAnyAsync<DbUpdateException>(() => db2.SaveChangesAsync());
    }

    [Fact]
    public async Task SosDeliveryAttempts_RejectsDuplicateSmsRowForSameContactAndChannel()
    {
        // WR-04 regression: RecipientUserId is always NULL on SMS/EmergencyContact rows, so a
        // single composite unique index across both RecipientUserId and EmergencyContactId never
        // actually constrained these rows (NULL is never equal to NULL in a SQL unique index) —
        // the two filtered indexes on SosDeliveryAttemptConfiguration must each enforce
        // "one row per (session, recipient, channel)" independently.
        await using var db = _factory.CreateContext();
        var (familyId, userId) = await SeedFamilyAndUser(db);

        var sessionId = Guid.NewGuid();
        db.SosSessions.Add(new SosSession
        {
            Id = sessionId,
            FamilyId = familyId,
            TriggeredByUserId = userId,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        var contactId = Guid.NewGuid();
        db.EmergencyContacts.Add(new EmergencyContact
        {
            Id = contactId,
            OwnerUserId = userId,
            DisplayName = "Mom",
            PhoneNumberE164 = "+15551234567",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            EmergencyContactId = contactId,
            Channel = AlertChannel.Sms,
        });
        await db.SaveChangesAsync();

        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            EmergencyContactId = contactId,
            Channel = AlertChannel.Sms,
        });

        await Assert.ThrowsAnyAsync<DbUpdateException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task UserDeviceToken_AllowsMultipleTokensPerUser()
    {
        await using var db = _factory.CreateContext();
        var (_, userId) = await SeedFamilyAndUser(db);

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

    private static async Task<(Guid FamilyId, Guid UserId)> SeedFamilyAndUser(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        db.Users.Add(new User { Id = userId, Email = "sos-test@example.com", FullName = "Sos Test", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "SOS Test Family", CreatedByUserId = userId, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();

        return (familyId, userId);
    }

    public void Dispose() => _factory.Dispose();
}
