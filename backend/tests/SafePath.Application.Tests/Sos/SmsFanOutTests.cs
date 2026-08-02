using Microsoft.EntityFrameworkCore;
using Moq;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Sos;

/// <summary>
/// Covers 03-05's widened recipient resolution (Guardians + emergency contacts), the SMS arm of
/// SosAlertDispatcher, and LoggingSmsGateway's zero-cost default behaviour.
/// </summary>
public class SmsFanOutTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Resolve_IncludesActiveEmergencyContactsOfTheTriggeringUser()
    {
        await using var db = _factory.CreateContext();
        var (familyId, callerId) = await SeedCallerOnlyFamily(db);
        var activeContact1 = await SeedContact(db, callerId, "Active One", isActive: true);
        var activeContact2 = await SeedContact(db, callerId, "Active Two", isActive: true);
        await SeedContact(db, callerId, "Inactive", isActive: false);

        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());

        await handler.Handle(new TriggerSosCommand(Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var smsAttempts = db.SosDeliveryAttempts.Where(a => a.Channel == AlertChannel.Sms).ToList();
        Assert.Equal(2, smsAttempts.Count);
        Assert.Contains(smsAttempts, a => a.EmergencyContactId == activeContact1);
        Assert.Contains(smsAttempts, a => a.EmergencyContactId == activeContact2);
    }

    [Fact]
    public async Task Resolve_IncludesGuardiansAndContactsAndNobodyElse()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var plainMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow },
            new User { Id = plainMemberId, Email = $"member-{plainMemberId}@example.com", FullName = "Plain Member", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Fan-out Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = callerId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = plainMemberId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        await db.SaveChangesAsync();

        var contactId = await SeedContact(db, callerId, "Emergency Contact", isActive: true);

        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        await handler.Handle(new TriggerSosCommand(Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var attempts = db.SosDeliveryAttempts.ToList();
        Assert.Contains(attempts, a => a.RecipientUserId == guardianId && a.Channel == AlertChannel.SignalR);
        Assert.Contains(attempts, a => a.EmergencyContactId == contactId && a.Channel == AlertChannel.Sms);
        Assert.DoesNotContain(attempts, a => a.RecipientUserId == plainMemberId);
    }

    [Fact]
    public async Task Resolve_DoesNotConsultSharingPreferences()
    {
        await using var db = _factory.CreateContext();
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();
        var guardianId = Guid.NewGuid();
        var guardianMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = guardianId, Email = $"guardian-{guardianId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Privacy Family", CreatedByUserId = guardianId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember { Id = Guid.NewGuid(), FamilyId = familyId, UserId = callerId, Role = Role.Member, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true },
            new FamilyMember { Id = guardianMemberId, FamilyId = familyId, UserId = guardianId, Role = Role.Guardian, Permissions = PermissionLevel.FullLocation, JoinedAt = DateTime.UtcNow, IsActive = true });
        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            OwnerUserId = callerId,
            RecipientMemberId = guardianMemberId,
            DataType = SharedDataType.LiveLocation,
            IsEnabled = false,
        });
        await db.SaveChangesAsync();

        var handler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        await handler.Handle(new TriggerSosCommand(Guid.NewGuid(), callerId, familyId, null, null, null, DateTime.UtcNow));

        var attempts = db.SosDeliveryAttempts.ToList();
        Assert.Contains(attempts, a => a.RecipientUserId == guardianId);
    }

    [Fact]
    public async Task Dispatch_MarksSmsQueuedAndStoresTheProviderMessageId()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, contactId) = await SeedSessionWithOneSmsAttempt(db);
        var gateway = new Mock<ISmsGateway>();
        gateway
            .Setup(g => g.SendAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new SmsSendResult("SM123"));
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), gateway.Object);

        await dispatcher.DispatchAsync(sessionId);

        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId && a.EmergencyContactId == contactId));
        Assert.Equal(SosDeliveryStatus.Queued, attempt.Status);
        Assert.Equal("SM123", attempt.ProviderMessageId);
        Assert.Null(attempt.DeliveredAtUtc);
    }

    [Fact]
    public async Task Dispatch_MarksSmsFailedWhenTheGatewayThrows()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, contactId) = await SeedSessionWithOneSmsAttempt(db);

        var signalRRecipientId = Guid.NewGuid();
        db.Users.Add(new User { Id = signalRRecipientId, Email = $"guardian-{signalRRecipientId}@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            RecipientUserId = signalRRecipientId,
            Channel = AlertChannel.SignalR,
            Status = SosDeliveryStatus.NotAttempted,
        });
        await db.SaveChangesAsync();

        var gateway = new Mock<ISmsGateway>();
        gateway
            .Setup(g => g.SendAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new InvalidOperationException("simulated provider failure"));
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.SosTriggered(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosSessionDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, gateway.Object);

        await dispatcher.DispatchAsync(sessionId);

        var smsAttempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.EmergencyContactId == contactId));
        Assert.Equal(SosDeliveryStatus.Failed, smsAttempt.Status);
        Assert.False(string.IsNullOrWhiteSpace(smsAttempt.FailureReason));

        var signalRAttempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.RecipientUserId == signalRRecipientId));
        Assert.Equal(SosDeliveryStatus.Queued, signalRAttempt.Status);
    }

    [Fact]
    public async Task LoggingGateway_ReturnsASyntheticIdAndSendsNothing()
    {
        var gateway = new SafePath.Infrastructure.Sms.LoggingSmsGateway(
            Microsoft.Extensions.Logging.Abstractions.NullLogger<SafePath.Infrastructure.Sms.LoggingSmsGateway>.Instance);

        var result = await gateway.SendAsync("+12025550182", "test body");

        Assert.False(string.IsNullOrWhiteSpace(result.ProviderMessageId));
    }

    [Fact]
    public async Task Message_ContainsSenderNameAndALocationLink()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _) = await SeedSessionWithOneSmsAttempt(db, latitude: 30.0444, longitude: 31.2357, senderDisplayName: "Alex Sender");

        string? capturedBody = null;
        var gateway = new Mock<ISmsGateway>();
        gateway
            .Setup(g => g.SendAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Callback<string, string, CancellationToken>((_, body, _) => capturedBody = body)
            .ReturnsAsync(new SmsSendResult("SM123"));
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), gateway.Object);

        await dispatcher.DispatchAsync(sessionId);

        Assert.NotNull(capturedBody);
        Assert.Contains("Alex Sender", capturedBody);
        Assert.Contains("30.0444", capturedBody);
        Assert.Contains("31.2357", capturedBody);
        Assert.DoesNotContain("+1", capturedBody);
    }

    private static async Task<(Guid FamilyId, Guid CallerId)> SeedCallerOnlyFamily(ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var callerId = Guid.NewGuid();

        db.Users.Add(new User { Id = callerId, Email = $"caller-{callerId}@example.com", FullName = "Caller", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Contacts Family", CreatedByUserId = callerId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = callerId,
            Role = Role.Member,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });

        await db.SaveChangesAsync();
        return (familyId, callerId);
    }

    private static async Task<Guid> SeedContact(ApplicationDbContext db, Guid ownerUserId, string displayName, bool isActive)
    {
        var contactId = Guid.NewGuid();
        db.EmergencyContacts.Add(new EmergencyContact
        {
            Id = contactId,
            OwnerUserId = ownerUserId,
            DisplayName = displayName,
            PhoneNumberE164 = "+12025550182",
            IsActive = isActive,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await db.SaveChangesAsync();
        return contactId;
    }

    private static async Task<(Guid FamilyId, Guid SosSessionId, Guid ContactId)> SeedSessionWithOneSmsAttempt(
        ApplicationDbContext db,
        double? latitude = null,
        double? longitude = null,
        string senderDisplayName = "Sender")
    {
        var familyId = Guid.NewGuid();
        var triggeredByUserId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var contactId = Guid.NewGuid();

        db.Users.Add(new User
        {
            Id = triggeredByUserId,
            Email = $"sender-{triggeredByUserId}@example.com",
            FullName = senderDisplayName,
            Role = Role.Member,
            CreatedAt = DateTime.UtcNow,
        });
        db.Families.Add(new Family { Id = familyId, Name = "Sms Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });
        db.SosSessions.Add(new SosSession
        {
            Id = sessionId,
            FamilyId = familyId,
            TriggeredByUserId = triggeredByUserId,
            Kind = SosKind.Visible,
            Status = SosSessionStatus.Active,
            Latitude = latitude,
            Longitude = longitude,
            TriggeredAtUtc = DateTime.UtcNow,
            ReceivedAtUtc = DateTime.UtcNow,
        });
        db.EmergencyContacts.Add(new EmergencyContact
        {
            Id = contactId,
            OwnerUserId = triggeredByUserId,
            DisplayName = "Contact",
            PhoneNumberE164 = "+12025550182",
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        db.SosDeliveryAttempts.Add(new SosDeliveryAttempt
        {
            Id = Guid.NewGuid(),
            SosSessionId = sessionId,
            EmergencyContactId = contactId,
            Channel = AlertChannel.Sms,
            Status = SosDeliveryStatus.NotAttempted,
        });

        await db.SaveChangesAsync();
        return (familyId, sessionId, contactId);
    }

    public void Dispose() => _factory.Dispose();
}
