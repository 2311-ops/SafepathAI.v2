using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Privacy;

public record UpdateSharingPreferenceCommand(
    Guid CallerUserId,
    Guid FamilyId,
    Guid? RecipientMemberId,
    SharedDataType DataType,
    bool IsEnabled,
    DateTime? ExpiresAtUtc);

public class UpdateSharingPreferenceCommandHandler : ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public UpdateSharingPreferenceCommandHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<SharingPreferenceDto> Handle(UpdateSharingPreferenceCommand command, CancellationToken cancellationToken = default)
    {
        await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, cancellationToken);

        string? recipientName = null;
        if (command.RecipientMemberId is { } recipientMemberId)
        {
            var recipient = await (
                from member in _db.FamilyMembers
                join user in _db.Users on member.UserId equals user.Id
                where member.Id == recipientMemberId && member.FamilyId == command.FamilyId && member.IsActive
                select new { user.FullName })
                .SingleOrDefaultAsync(cancellationToken);

            if (recipient is null)
            {
                throw new FamilyAuthorizationDeniedException(
                    $"FamilyMember {recipientMemberId} is not an active member of family {command.FamilyId}.");
            }

            recipientName = recipient.FullName;
        }

        var preference = await _db.SharingPreferences.FirstOrDefaultAsync(
            p => p.FamilyId == command.FamilyId &&
                p.OwnerUserId == command.CallerUserId &&
                p.RecipientMemberId == command.RecipientMemberId &&
                p.DataType == command.DataType,
            cancellationToken);

        if (preference is null)
        {
            preference = new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = command.FamilyId,
                OwnerUserId = command.CallerUserId,
                RecipientMemberId = command.RecipientMemberId,
                DataType = command.DataType,
            };
            _db.SharingPreferences.Add(preference);
        }

        preference.IsEnabled = command.IsEnabled;
        preference.ExpiresAtUtc = command.ExpiresAtUtc;

        await _db.SaveChangesAsync(cancellationToken);

        return new SharingPreferenceDto(
            preference.RecipientMemberId,
            recipientName,
            preference.DataType,
            preference.IsEnabled,
            preference.ExpiresAtUtc);
    }
}
