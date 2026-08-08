using Microsoft.EntityFrameworkCore;
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
/// Asserts the recipient-scoping rule for <see cref="SosSessionDto.TriggeredByPhoneNumberE164"/>
/// (T-RK2-01) end-to-end through the real handlers — never by calling
/// <see cref="SosSessionProjection"/> directly. A real trigger drives genuine
/// <see cref="SosDeliveryAttempt"/> rows so "recipient" means exactly what production means.
/// </summary>
public class SosSenderPhoneVisibilityTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task GetSosSession_ByAnActualRecipientGuardian_ReturnsSendersStoredNumber()
    {
        await using var db = _factory.CreateContext();
        var (familyId, senderId, recipientId, _) = await SeedFamily(db, senderPhoneNumber: "+12025550173");
        var triggerHandler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        var sosSessionId = Guid.NewGuid();
        await triggerHandler.Handle(new TriggerSosCommand(sosSessionId, senderId, familyId, null, null, null, DateTime.UtcNow));

        var queryHandler = new GetSosSessionQueryHandler(db, new FamilyAuthorizationService(db));
        var result = await queryHandler.Handle(new GetSosSessionQuery(recipientId, sosSessionId));

        Assert.Equal("+12025550173", result.Session!.TriggeredByPhoneNumberE164);
    }

    [Fact]
    public async Task GetSosSession_ByTheTriggeringUserThemselves_ReturnsNull()
    {
        await using var db = _factory.CreateContext();
        var (familyId, senderId, _, _) = await SeedFamily(db, senderPhoneNumber: "+12025550173");
        var triggerHandler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        var sosSessionId = Guid.NewGuid();
        await triggerHandler.Handle(new TriggerSosCommand(sosSessionId, senderId, familyId, null, null, null, DateTime.UtcNow));

        var queryHandler = new GetSosSessionQueryHandler(db, new FamilyAuthorizationService(db));
        var result = await queryHandler.Handle(new GetSosSessionQuery(senderId, sosSessionId));

        Assert.Null(result.Session!.TriggeredByPhoneNumberE164);
    }

    [Fact]
    public async Task GetSosSession_ByAMemberWithNoDeliveryAttemptRow_ReturnsNullDespitePassingMembership()
    {
        await using var db = _factory.CreateContext();
        var (familyId, senderId, _, nonRecipientMemberId) = await SeedFamily(db, senderPhoneNumber: "+12025550173");
        var triggerHandler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        var sosSessionId = Guid.NewGuid();
        await triggerHandler.Handle(new TriggerSosCommand(sosSessionId, senderId, familyId, null, null, null, DateTime.UtcNow));

        var queryHandler = new GetSosSessionQueryHandler(db, new FamilyAuthorizationService(db));
        var result = await queryHandler.Handle(new GetSosSessionQuery(nonRecipientMemberId, sosSessionId));

        Assert.Null(result.Session!.TriggeredByPhoneNumberE164);
        Assert.DoesNotContain(result.Session.Recipients, r => r.RecipientUserId == nonRecipientMemberId);
    }

    [Fact]
    public async Task GetSosSession_ByAGenuineRecipient_ReturnsNullWhenSenderNeverStoredANumber()
    {
        await using var db = _factory.CreateContext();
        var (familyId, senderId, recipientId, _) = await SeedFamily(db, senderPhoneNumber: null);
        var triggerHandler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        var sosSessionId = Guid.NewGuid();
        await triggerHandler.Handle(new TriggerSosCommand(sosSessionId, senderId, familyId, null, null, null, DateTime.UtcNow));

        var queryHandler = new GetSosSessionQueryHandler(db, new FamilyAuthorizationService(db));
        var result = await queryHandler.Handle(new GetSosSessionQuery(recipientId, sosSessionId));

        Assert.Null(result.Session!.TriggeredByPhoneNumberE164);
    }

    [Fact]
    public async Task TriggerSosCommand_FreshAndIdempotentReplay_CarryNullForTheSender()
    {
        await using var db = _factory.CreateContext();
        var (familyId, senderId, _, _) = await SeedFamily(db, senderPhoneNumber: "+12025550173");
        var triggerHandler = new TriggerSosCommandHandler(db, new FamilyAuthorizationService(db), new NoOpSosAlertDispatcher());
        var command = new TriggerSosCommand(Guid.NewGuid(), senderId, familyId, null, null, null, DateTime.UtcNow);

        var fresh = await triggerHandler.Handle(command);
        var replay = await triggerHandler.Handle(command);

        Assert.False(fresh.WasExistingSession);
        Assert.True(replay.WasExistingSession);
        Assert.Null(fresh.Session.TriggeredByPhoneNumberE164);
        Assert.Null(replay.Session.TriggeredByPhoneNumberE164);
    }

    private static async Task<(Guid FamilyId, Guid SenderId, Guid RecipientId, Guid NonRecipientMemberId)> SeedFamily(
        ApplicationDbContext db,
        string? senderPhoneNumber)
    {
        var familyId = Guid.NewGuid();
        var senderId = Guid.NewGuid();
        var recipientId = Guid.NewGuid();
        var nonRecipientMemberId = Guid.NewGuid();

        db.Users.Add(new User
        {
            Id = senderId,
            Email = "sender@example.com",
            FullName = "Sender",
            Role = Role.Member,
            PhoneNumberE164 = senderPhoneNumber,
            CreatedAt = DateTime.UtcNow,
        });
        db.Users.Add(new User { Id = recipientId, Email = "guardian@example.com", FullName = "Guardian", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Users.Add(new User { Id = nonRecipientMemberId, Email = "sibling@example.com", FullName = "Sibling", Role = Role.Member, CreatedAt = DateTime.UtcNow });

        db.Families.Add(new Family { Id = familyId, Name = "Visibility Family", CreatedByUserId = senderId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = senderId,
            Role = Role.Member,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow.AddMinutes(-3),
            IsActive = true,
        });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = recipientId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow.AddMinutes(-2),
            IsActive = true,
        });
        // Passes membership (RequireMembership) but is never resolved as an SOS recipient — only
        // active Guardians are, so a plain active Member never gets a delivery-attempt row.
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            UserId = nonRecipientMemberId,
            Role = Role.Member,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow.AddMinutes(-1),
            IsActive = true,
        });

        await db.SaveChangesAsync();
        return (familyId, senderId, recipientId, nonRecipientMemberId);
    }

    public void Dispose() => _factory.Dispose();
}
