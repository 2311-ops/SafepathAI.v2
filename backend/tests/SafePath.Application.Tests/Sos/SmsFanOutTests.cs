using System.Net;
using System.Net.Http;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
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
/// SosAlertDispatcher, LoggingSmsGateway's zero-cost default behaviour, and the delivery-status
/// webhook that is the only path allowed to mark an SMS row Delivered.
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
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), gateway.Object, new NoOpPushSender());

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
        var dispatcher = new SosAlertDispatcher(db, broadcast.Object, gateway.Object, new NoOpPushSender());

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
    public void WhatsAppWebhookSignatureValidator_ValidatesACorrectlyComputedSignature()
    {
        var validator = new SafePath.Infrastructure.Sms.WhatsAppWebhookSignatureValidator(
            new SafePath.Infrastructure.Sms.WhatsAppOptions { AppSecret = "test-secret" });
        var body = "{\"entry\":[]}";
        var signature = "sha256=" + ComputeHexHmac("test-secret", body);

        Assert.True(validator.IsValid(body, signature));
    }

    [Fact]
    public void WhatsAppWebhookSignatureValidator_RejectsATamperedBody()
    {
        var validator = new SafePath.Infrastructure.Sms.WhatsAppWebhookSignatureValidator(
            new SafePath.Infrastructure.Sms.WhatsAppOptions { AppSecret = "test-secret" });
        var signature = "sha256=" + ComputeHexHmac("test-secret", "{\"entry\":[]}");

        Assert.False(validator.IsValid("{\"entry\":[{\"tampered\":true}]}", signature));
    }

    [Fact]
    public void WhatsAppWebhookSignatureValidator_RefusesACorrectlySignedBodyWhenNoAppSecretIsConfigured()
    {
        var validator = new SafePath.Infrastructure.Sms.WhatsAppWebhookSignatureValidator(
            new SafePath.Infrastructure.Sms.WhatsAppOptions { AppSecret = null });
        var body = "{\"entry\":[]}";
        var signature = "sha256=" + ComputeHexHmac("test-secret", body);

        Assert.False(validator.IsValid(body, signature));
    }

    [Fact]
    public void WhatsAppDeliveryStatusParser_ParsesADeliveredStatus()
    {
        var parser = new SafePath.Infrastructure.Sms.WhatsAppDeliveryStatusParser();
        var payload = BuildStatusPayload("wamid.ABC", "delivered");

        var updates = parser.Parse(payload);

        var update = Assert.Single(updates);
        Assert.Equal("wamid.ABC", update.ProviderMessageId);
        Assert.Equal(SmsDeliveryOutcome.Delivered, update.Outcome);
    }

    [Fact]
    public void WhatsAppDeliveryStatusParser_ParsesAReadStatusAsDelivered()
    {
        var parser = new SafePath.Infrastructure.Sms.WhatsAppDeliveryStatusParser();
        var payload = BuildStatusPayload("wamid.ABC", "read");

        var updates = parser.Parse(payload);

        var update = Assert.Single(updates);
        Assert.Equal(SmsDeliveryOutcome.Delivered, update.Outcome);
    }

    [Fact]
    public void WhatsAppDeliveryStatusParser_ParsesAFailedStatusWithAnErrorCode()
    {
        var parser = new SafePath.Infrastructure.Sms.WhatsAppDeliveryStatusParser();
        var payload = "{\"entry\":[{\"changes\":[{\"value\":{\"statuses\":[{\"id\":\"wamid.ABC\",\"status\":\"failed\",\"errors\":[{\"code\":131047,\"title\":\"Re-engagement message\"}]}]}}]}]}";

        var updates = parser.Parse(payload);

        var update = Assert.Single(updates);
        Assert.Equal(SmsDeliveryOutcome.Failed, update.Outcome);
        Assert.Equal("131047", update.FailureReason);
    }

    [Fact]
    public void WhatsAppDeliveryStatusParser_YieldsNoUpdateForASentStatus()
    {
        var parser = new SafePath.Infrastructure.Sms.WhatsAppDeliveryStatusParser();
        var payload = BuildStatusPayload("wamid.ABC", "sent");

        var updates = parser.Parse(payload);

        Assert.Empty(updates);
    }

    [Fact]
    public void WhatsAppDeliveryStatusParser_ReturnsAnEmptyListForMalformedInput()
    {
        var parser = new SafePath.Infrastructure.Sms.WhatsAppDeliveryStatusParser();

        var updates = parser.Parse("not valid json");

        Assert.Empty(updates);
    }

    private static string BuildStatusPayload(string messageId, string status) =>
        $"{{\"entry\":[{{\"changes\":[{{\"value\":{{\"statuses\":[{{\"id\":\"{messageId}\",\"status\":\"{status}\"}}]}}}}]}}]}}";

    private static string ComputeHexHmac(string secret, string body)
    {
        var hashBytes = System.Security.Cryptography.HMACSHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(secret),
            System.Text.Encoding.UTF8.GetBytes(body));
        return Convert.ToHexStringLower(hashBytes);
    }

    [Fact]
    public async Task WhatsAppSmsGateway_SendsATemplateMessageAndExtractsTheMessageId()
    {
        var captured = new List<HttpRequestMessage>();
        var capturedBodies = new List<string>();
        var handler = new CapturingHttpMessageHandler(captured, capturedBodies, () =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { messaging_product = "whatsapp", messages = new[] { new { id = "wamid.TEST" } } }),
            };
            return response;
        });

        var gateway = new SafePath.Infrastructure.Sms.WhatsAppSmsGateway(
            new HttpClient(handler) { BaseAddress = new Uri("https://graph.facebook.com/") },
            new SafePath.Infrastructure.Sms.WhatsAppOptions
            {
                AccessToken = "test-token",
                PhoneNumberId = "test-phone-number-id",
                TemplateName = "sos_alert",
                TemplateLanguage = "en",
                ApiVersion = "v22.0",
            },
            NullLogger<SafePath.Infrastructure.Sms.WhatsAppSmsGateway>.Instance);

        var result = await gateway.SendAsync("+12025550182", "test body");

        var request = Assert.Single(captured);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Contains("test-phone-number-id", request.RequestUri!.AbsolutePath);
        Assert.EndsWith("/messages", request.RequestUri!.AbsolutePath);
        Assert.Equal("Bearer", request.Headers.Authorization?.Scheme);
        Assert.Equal("test-token", request.Headers.Authorization?.Parameter);
        Assert.Equal("wamid.TEST", result.ProviderMessageId);
    }

    [Fact]
    public async Task WhatsAppSmsGateway_NormalizesWhitespaceInTheTemplateParameter()
    {
        var captured = new List<HttpRequestMessage>();
        var capturedBodies = new List<string>();
        var handler = new CapturingHttpMessageHandler(captured, capturedBodies, () =>
        {
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { messaging_product = "whatsapp", messages = new[] { new { id = "wamid.TEST" } } }),
            };
            return response;
        });

        var gateway = new SafePath.Infrastructure.Sms.WhatsAppSmsGateway(
            new HttpClient(handler) { BaseAddress = new Uri("https://graph.facebook.com/") },
            new SafePath.Infrastructure.Sms.WhatsAppOptions
            {
                AccessToken = "test-token",
                PhoneNumberId = "test-phone-number-id",
                TemplateName = "sos_alert",
                TemplateLanguage = "en",
                ApiVersion = "v22.0",
            },
            NullLogger<SafePath.Infrastructure.Sms.WhatsAppSmsGateway>.Instance);

        await gateway.SendAsync("+12025550182", "Line one\nLine two\twith a\t\ttab and    spaces");

        var body = Assert.Single(capturedBodies);
        Assert.DoesNotContain('\n', body);
        Assert.DoesNotContain('\t', body);
    }

    private sealed class CapturingHttpMessageHandler : HttpMessageHandler
    {
        private readonly List<HttpRequestMessage> _captured;
        private readonly List<string>? _capturedBodies;
        private readonly Func<HttpResponseMessage> _responseFactory;

        public CapturingHttpMessageHandler(List<HttpRequestMessage> captured, Func<HttpResponseMessage> responseFactory)
            : this(captured, null, responseFactory)
        {
        }

        public CapturingHttpMessageHandler(List<HttpRequestMessage> captured, List<string>? capturedBodies, Func<HttpResponseMessage> responseFactory)
        {
            _captured = captured;
            _capturedBodies = capturedBodies;
            _responseFactory = responseFactory;
        }

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            _captured.Add(request);
            if (_capturedBodies is not null && request.Content is not null)
            {
                _capturedBodies.Add(await request.Content.ReadAsStringAsync(cancellationToken));
            }

            return _responseFactory();
        }
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
        var dispatcher = new SosAlertDispatcher(db, Mock.Of<IAlertBroadcastService>(), gateway.Object, new NoOpPushSender());

        await dispatcher.DispatchAsync(sessionId);

        Assert.NotNull(capturedBody);
        Assert.Contains("Alex Sender", capturedBody);
        Assert.Contains("30.0444", capturedBody);
        Assert.Contains("31.2357", capturedBody);
        Assert.DoesNotContain("+1", capturedBody);
    }

    [Fact]
    public async Task Webhook_MarksTheMatchingRowDeliveredOnADeliveredStatus()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _, providerMessageId) = await SeedQueuedSmsAttempt(db);
        var parser = new FakeDeliveryStatusParser(new[] { new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Delivered, null) });
        var handler = new RecordSmsDeliveryStatusCommandHandler(db, Mock.Of<IAlertBroadcastService>(), new FakeSignatureValidator(isValid: true), parser);

        var result = await handler.Handle(new RecordSmsDeliveryStatusCommand("{}", "any-signature"));

        Assert.True(result.Applied);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId));
        Assert.Equal(SosDeliveryStatus.Delivered, attempt.Status);
        Assert.NotNull(attempt.DeliveredAtUtc);
    }

    [Fact]
    public async Task Webhook_MarksTheMatchingRowFailedOnAFailedStatus()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _, providerMessageId) = await SeedQueuedSmsAttempt(db);
        var parser = new FakeDeliveryStatusParser(new[] { new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Failed, "131047") });
        var handler = new RecordSmsDeliveryStatusCommandHandler(db, Mock.Of<IAlertBroadcastService>(), new FakeSignatureValidator(isValid: true), parser);

        var result = await handler.Handle(new RecordSmsDeliveryStatusCommand("{}", "any-signature"));

        Assert.True(result.Applied);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId));
        Assert.Equal(SosDeliveryStatus.Failed, attempt.Status);
        Assert.Equal("131047", attempt.FailureReason);
    }

    [Fact]
    public async Task Webhook_IgnoresAnUnknownProviderMessageId()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _, _) = await SeedQueuedSmsAttempt(db);
        var parser = new FakeDeliveryStatusParser(new[] { new SmsDeliveryStatusUpdate("SM-unknown", SmsDeliveryOutcome.Delivered, null) });
        var handler = new RecordSmsDeliveryStatusCommandHandler(db, Mock.Of<IAlertBroadcastService>(), new FakeSignatureValidator(isValid: true), parser);

        var result = await handler.Handle(new RecordSmsDeliveryStatusCommand("{}", "any-signature"));

        Assert.True(result.SignatureValid);
        Assert.False(result.Applied);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId));
        Assert.Equal(SosDeliveryStatus.Queued, attempt.Status);
    }

    [Fact]
    public async Task Webhook_RejectsAnInvalidSignature()
    {
        await using var db = _factory.CreateContext();
        var (_, sessionId, _, _, providerMessageId) = await SeedQueuedSmsAttempt(db);
        var parser = new FakeDeliveryStatusParser(new[] { new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Delivered, null) });
        var handler = new RecordSmsDeliveryStatusCommandHandler(db, Mock.Of<IAlertBroadcastService>(), new FakeSignatureValidator(isValid: false), parser);

        var result = await handler.Handle(new RecordSmsDeliveryStatusCommand("{}", "forged-signature"));

        Assert.False(result.SignatureValid);
        Assert.False(result.Applied);
        var attempt = Assert.Single(db.SosDeliveryAttempts.Where(a => a.SosSessionId == sessionId));
        Assert.Equal(SosDeliveryStatus.Queued, attempt.Status);
    }

    [Fact]
    public async Task Webhook_BroadcastsTheStatusChangeToTheSender()
    {
        await using var db = _factory.CreateContext();
        var (familyId, sessionId, triggeredByUserId, _, providerMessageId) = await SeedQueuedSmsAttempt(db);
        var broadcast = new Mock<IAlertBroadcastService>();
        broadcast
            .Setup(b => b.DeliveryStatusChanged(It.IsAny<Guid>(), It.IsAny<IEnumerable<Guid>>(), It.IsAny<SosDeliveryStatusChangedDto>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var parser = new FakeDeliveryStatusParser(new[] { new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Delivered, null) });
        var handler = new RecordSmsDeliveryStatusCommandHandler(db, broadcast.Object, new FakeSignatureValidator(isValid: true), parser);

        await handler.Handle(new RecordSmsDeliveryStatusCommand("{}", "any-signature"));

        broadcast.Verify(
            b => b.DeliveryStatusChanged(
                familyId,
                It.Is<IEnumerable<Guid>>(ids => ids.Contains(triggeredByUserId)),
                It.IsAny<SosDeliveryStatusChangedDto>(),
                It.IsAny<CancellationToken>()),
            Times.Once);
    }

    private static async Task<(Guid FamilyId, Guid SosSessionId, Guid TriggeredByUserId, Guid ContactId, string ProviderMessageId)> SeedQueuedSmsAttempt(
        ApplicationDbContext db)
    {
        var familyId = Guid.NewGuid();
        var triggeredByUserId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        var contactId = Guid.NewGuid();
        var providerMessageId = $"SM{Guid.NewGuid():N}";

        db.Users.Add(new User
        {
            Id = triggeredByUserId,
            Email = $"sender-{triggeredByUserId}@example.com",
            FullName = "Sender",
            Role = Role.Member,
            CreatedAt = DateTime.UtcNow,
        });
        db.Families.Add(new Family { Id = familyId, Name = "Webhook Family", CreatedByUserId = triggeredByUserId, CreatedAt = DateTime.UtcNow });
        db.SosSessions.Add(new SosSession
        {
            Id = sessionId,
            FamilyId = familyId,
            TriggeredByUserId = triggeredByUserId,
            Kind = SosKind.Visible,
            Status = SosSessionStatus.Active,
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
            Status = SosDeliveryStatus.Queued,
            QueuedAtUtc = DateTime.UtcNow,
            ProviderMessageId = providerMessageId,
        });

        await db.SaveChangesAsync();
        return (familyId, sessionId, triggeredByUserId, contactId, providerMessageId);
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

/// <summary>
/// Deterministic ISmsWebhookSignatureValidator test double. The real
/// WhatsAppWebhookSignatureValidator depends on a configured app secret and computes a real
/// HMAC-SHA256 over the raw body, so FakeSignatureValidator exists specifically to let these
/// tests exercise RecordSmsDeliveryStatusCommandHandler's own Delivered/Failed/ignore branching
/// under both a valid and an invalid signature outcome without needing to compute a real HMAC in
/// every handler test.
/// </summary>
internal sealed class FakeSignatureValidator : ISmsWebhookSignatureValidator
{
    private readonly bool _isValid;

    public FakeSignatureValidator(bool isValid)
    {
        _isValid = isValid;
    }

    public bool IsValid(string rawBody, string? signatureHeader) => _isValid;

    public bool IsVerificationTokenValid(string? verifyToken) => _isValid;
}

/// <summary>
/// Deterministic ISmsDeliveryStatusParser test double returning a fixed update list, so handler
/// tests can exercise Delivered/Failed/unknown-id branching without depending on the real
/// WhatsApp JSON payload shape.
/// </summary>
internal sealed class FakeDeliveryStatusParser : ISmsDeliveryStatusParser
{
    private readonly IReadOnlyList<SmsDeliveryStatusUpdate> _updates;

    public FakeDeliveryStatusParser(IReadOnlyList<SmsDeliveryStatusUpdate> updates)
    {
        _updates = updates;
    }

    public IReadOnlyList<SmsDeliveryStatusUpdate> Parse(string rawBody) => _updates;
}
