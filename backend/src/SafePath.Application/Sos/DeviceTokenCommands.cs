using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Sos;

/// <summary>
/// Registers (upserts) an FCM device token for the caller. Registration is keyed on the token
/// value itself, never on (UserId, Platform) — a device that already has a row simply has its
/// owner and freshness updated. Never deletes the caller's other token rows: that would silently
/// reintroduce the single-device model D-32 explicitly rejects (a guardian signed in on a phone
/// and a tablet must be alerted on both).
/// </summary>
public record RegisterDeviceTokenCommand(Guid CallerUserId, string Token, DevicePlatform Platform);

/// <summary>Removes only the row matching both the token and the caller — never another user's token.</summary>
public record RemoveDeviceTokenCommand(Guid CallerUserId, string Token);

public record RegisterDeviceTokenResult(Guid Id);

public class RegisterDeviceTokenCommandHandler : ICommandHandler<RegisterDeviceTokenCommand, RegisterDeviceTokenResult>
{
    private readonly IApplicationDbContext _db;

    public RegisterDeviceTokenCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<RegisterDeviceTokenResult> Handle(
        RegisterDeviceTokenCommand command,
        CancellationToken cancellationToken = default)
    {
        var token = ValidateToken(command.Token);
        var now = DateTime.UtcNow;

        var existing = await _db.UserDeviceTokens
            .SingleOrDefaultAsync(t => t.Token == token, cancellationToken);

        if (existing is not null)
        {
            // T-03-23 (Spoofing): reassign rather than reject, so a shared or re-flashed device
            // that used to belong to another user does not keep alerting the previous owner.
            existing.UserId = command.CallerUserId;
            existing.Platform = command.Platform;
            existing.LastSeenAtUtc = now;

            await _db.SaveChangesAsync(cancellationToken);
            return new RegisterDeviceTokenResult(existing.Id);
        }

        var row = new UserDeviceToken
        {
            Id = Guid.NewGuid(),
            UserId = command.CallerUserId,
            Token = token,
            Platform = command.Platform,
            CreatedAtUtc = now,
            LastSeenAtUtc = now,
        };

        _db.UserDeviceTokens.Add(row);
        await _db.SaveChangesAsync(cancellationToken);

        return new RegisterDeviceTokenResult(row.Id);
    }

    internal static string ValidateToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token))
        {
            throw new ArgumentException("Device token must not be empty.", nameof(token));
        }

        return token.Trim();
    }
}

public class RemoveDeviceTokenCommandHandler : ICommandHandler<RemoveDeviceTokenCommand, bool>
{
    private readonly IApplicationDbContext _db;

    public RemoveDeviceTokenCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<bool> Handle(RemoveDeviceTokenCommand command, CancellationToken cancellationToken = default)
    {
        var row = await _db.UserDeviceTokens
            .SingleOrDefaultAsync(
                t => t.Token == command.Token && t.UserId == command.CallerUserId,
                cancellationToken);

        if (row is null)
        {
            return false;
        }

        _db.UserDeviceTokens.Remove(row);
        await _db.SaveChangesAsync(cancellationToken);
        return true;
    }
}

/// <summary>
/// The FCM equivalent of <c>AlertHub.ConfirmReceipt</c>: a client asserting it received an SOS
/// push, upgrading its own (session, Fcm) delivery row to Delivered. Guarded by
/// <see cref="IFamilyAuthorizationService.RequireMembership"/> on the session's family.
/// </summary>
public record ConfirmPushReceiptCommand(Guid CallerUserId, Guid SosSessionId);

public record ConfirmPushReceiptResult(bool Applied);

public class ConfirmPushReceiptCommandHandler : ICommandHandler<ConfirmPushReceiptCommand, ConfirmPushReceiptResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;
    private readonly IAlertBroadcastService _broadcast;

    public ConfirmPushReceiptCommandHandler(
        IApplicationDbContext db,
        IFamilyAuthorizationService authorization,
        IAlertBroadcastService broadcast)
    {
        _db = db;
        _authorization = authorization;
        _broadcast = broadcast;
    }

    public async Task<ConfirmPushReceiptResult> Handle(
        ConfirmPushReceiptCommand command,
        CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions
            .SingleOrDefaultAsync(s => s.Id == command.SosSessionId, cancellationToken);
        if (session is null)
        {
            return new ConfirmPushReceiptResult(Applied: false);
        }

        await _authorization.RequireMembership(command.CallerUserId, session.FamilyId, cancellationToken);

        var attempt = await _db.SosDeliveryAttempts.SingleOrDefaultAsync(
            a => a.SosSessionId == command.SosSessionId
                && a.RecipientUserId == command.CallerUserId
                && a.Channel == AlertChannel.Fcm,
            cancellationToken);
        if (attempt is null)
        {
            return new ConfirmPushReceiptResult(Applied: false);
        }

        var deliveredAtUtc = DateTime.UtcNow;
        attempt.Status = SosDeliveryStatus.Delivered;
        attempt.DeliveredAtUtc = deliveredAtUtc;
        await _db.SaveChangesAsync(cancellationToken);

        var recipientUserIds = await SosSessionProjection.ResolveRecipientUserIds(_db, session.Id, cancellationToken);
        var broadcastRecipients = recipientUserIds.Append(session.TriggeredByUserId).Distinct();

        await _broadcast.DeliveryStatusChanged(
            session.FamilyId,
            broadcastRecipients,
            new SosDeliveryStatusChangedDto(
                command.SosSessionId,
                command.CallerUserId,
                null,
                AlertChannel.Fcm,
                SosDeliveryStatus.Delivered,
                deliveredAtUtc),
            cancellationToken);

        return new ConfirmPushReceiptResult(Applied: true);
    }
}
