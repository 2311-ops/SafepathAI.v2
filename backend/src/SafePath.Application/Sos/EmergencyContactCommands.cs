using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;

namespace SafePath.Application.Sos;

/// <summary>
/// Adds a new emergency contact owned exclusively by <see cref="CallerUserId"/>. The owner id is
/// always the authenticated caller (threat T-03-20) — no request payload ever sets it.
/// </summary>
public record AddEmergencyContactCommand(Guid CallerUserId, string DisplayName, string PhoneNumber, string? Region);

/// <summary>
/// Updates an existing contact. Throws <see cref="FamilyAuthorizationDeniedException"/> when
/// <see cref="ContactId"/> is not owned by <see cref="CallerUserId"/>.
/// </summary>
public record UpdateEmergencyContactCommand(Guid CallerUserId, Guid ContactId, string DisplayName, string PhoneNumber, string? Region);

/// <summary>
/// Soft-deactivates a contact (sets IsActive = false) rather than removing the row, so historic
/// SosDeliveryAttempt rows keep a resolvable recipient.
/// </summary>
public record DeleteEmergencyContactCommand(Guid CallerUserId, Guid ContactId);

/// <summary>Lists only the caller's own active contacts.</summary>
public record ListEmergencyContactsQuery(Guid CallerUserId);

public class AddEmergencyContactCommandHandler : ICommandHandler<AddEmergencyContactCommand, EmergencyContactDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IConfiguration? _configuration;

    public AddEmergencyContactCommandHandler(IApplicationDbContext db, IConfiguration? configuration = null)
    {
        _db = db;
        _configuration = configuration;
    }

    public async Task<EmergencyContactDto> Handle(AddEmergencyContactCommand command, CancellationToken cancellationToken = default)
    {
        var displayName = ValidateDisplayName(command.DisplayName);
        var defaultRegion = command.Region ?? _configuration?["Sms:DefaultRegion"];
        var phoneNumberE164 = PhoneNumberNormalizer.ToE164(command.PhoneNumber, defaultRegion);

        var now = DateTime.UtcNow;
        var contact = new EmergencyContact
        {
            Id = Guid.NewGuid(),
            OwnerUserId = command.CallerUserId,
            DisplayName = displayName,
            PhoneNumberE164 = phoneNumberE164,
            IsActive = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        };

        _db.EmergencyContacts.Add(contact);
        await _db.SaveChangesAsync(cancellationToken);

        return ToDto(contact);
    }

    internal static string ValidateDisplayName(string displayName)
    {
        var trimmed = displayName?.Trim() ?? string.Empty;
        if (trimmed.Length is < 1 or > 120)
        {
            throw new ArgumentException("Display name must be between 1 and 120 characters.", nameof(displayName));
        }

        return trimmed;
    }

    internal static EmergencyContactDto ToDto(EmergencyContact contact) =>
        new(contact.Id, contact.DisplayName, contact.PhoneNumberE164, contact.IsActive);
}

public class UpdateEmergencyContactCommandHandler : ICommandHandler<UpdateEmergencyContactCommand, EmergencyContactDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IConfiguration? _configuration;

    public UpdateEmergencyContactCommandHandler(IApplicationDbContext db, IConfiguration? configuration = null)
    {
        _db = db;
        _configuration = configuration;
    }

    public async Task<EmergencyContactDto> Handle(UpdateEmergencyContactCommand command, CancellationToken cancellationToken = default)
    {
        var contact = await _db.EmergencyContacts
            .SingleOrDefaultAsync(c => c.Id == command.ContactId, cancellationToken);

        if (contact is null || contact.OwnerUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException(
                $"EmergencyContact {command.ContactId} is not owned by the caller.");
        }

        var displayName = AddEmergencyContactCommandHandler.ValidateDisplayName(command.DisplayName);
        var defaultRegion = command.Region ?? _configuration?["Sms:DefaultRegion"];
        var phoneNumberE164 = PhoneNumberNormalizer.ToE164(command.PhoneNumber, defaultRegion);

        contact.DisplayName = displayName;
        contact.PhoneNumberE164 = phoneNumberE164;
        contact.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync(cancellationToken);

        return AddEmergencyContactCommandHandler.ToDto(contact);
    }
}

public class DeleteEmergencyContactCommandHandler : ICommandHandler<DeleteEmergencyContactCommand, EmergencyContactDto>
{
    private readonly IApplicationDbContext _db;

    public DeleteEmergencyContactCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<EmergencyContactDto> Handle(DeleteEmergencyContactCommand command, CancellationToken cancellationToken = default)
    {
        var contact = await _db.EmergencyContacts
            .SingleOrDefaultAsync(c => c.Id == command.ContactId, cancellationToken);

        if (contact is null || contact.OwnerUserId != command.CallerUserId)
        {
            throw new FamilyAuthorizationDeniedException(
                $"EmergencyContact {command.ContactId} is not owned by the caller.");
        }

        contact.IsActive = false;
        contact.UpdatedAtUtc = DateTime.UtcNow;

        await _db.SaveChangesAsync(cancellationToken);

        return AddEmergencyContactCommandHandler.ToDto(contact);
    }
}

public class ListEmergencyContactsQueryHandler : ICommandHandler<ListEmergencyContactsQuery, IReadOnlyList<EmergencyContactDto>>
{
    private readonly IApplicationDbContext _db;

    public ListEmergencyContactsQueryHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<EmergencyContactDto>> Handle(ListEmergencyContactsQuery query, CancellationToken cancellationToken = default)
    {
        return await _db.EmergencyContacts
            .Where(c => c.OwnerUserId == query.CallerUserId && c.IsActive)
            .OrderBy(c => c.DisplayName)
            .Select(c => new EmergencyContactDto(c.Id, c.DisplayName, c.PhoneNumberE164, c.IsActive))
            .ToListAsync(cancellationToken);
    }
}
