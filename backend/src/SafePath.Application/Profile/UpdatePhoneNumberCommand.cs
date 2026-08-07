using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using SafePath.Application.Common;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Sos;
using SafePath.Domain.Entities;

namespace SafePath.Application.Profile;

/// <summary>
/// Sets or clears the caller's own stored phone number. A null/blank <see cref="PhoneNumber"/>
/// clears the stored value back to null rather than throwing, keeping the field genuinely
/// optional and removable.
/// </summary>
public record UpdatePhoneNumberCommand(Guid CallerUserId, string? PhoneNumber, string? Region = null);

/// <summary>
/// Mirrors <see cref="UpdateDisplayNameCommandHandler"/>'s shape (load-by-caller-id, save,
/// project via <see cref="ProfileProjection.FromUser"/>), but deliberately diverges from it in
/// two ways: it does NOT stamp <see cref="User.ProfileUpdatedAt"/>, and it does NOT call
/// <see cref="ProfileProjection.BroadcastUpdatedAsync"/>. The phone number is not a member of
/// <see cref="ProfileUpdateDto"/> and no family member can ever see it — stamping the shared
/// profile timestamp would needlessly invalidate every family member's cached avatar for a
/// change that is invisible to them.
/// </summary>
public class UpdatePhoneNumberCommandHandler : ICommandHandler<UpdatePhoneNumberCommand, GetMeResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IConfiguration? _configuration;

    public UpdatePhoneNumberCommandHandler(IApplicationDbContext db, IConfiguration? configuration = null)
    {
        _db = db;
        _configuration = configuration;
    }

    public async Task<GetMeResult> Handle(UpdatePhoneNumberCommand command, CancellationToken cancellationToken = default)
    {
        var user = await LoadUser(command.CallerUserId, cancellationToken);

        if (string.IsNullOrWhiteSpace(command.PhoneNumber))
        {
            user.PhoneNumberE164 = null;
        }
        else
        {
            var region = command.Region ?? _configuration?["Sms:DefaultRegion"];
            user.PhoneNumberE164 = PhoneNumberNormalizer.ToE164(command.PhoneNumber, region);
        }

        await _db.SaveChangesAsync(cancellationToken);

        return ProfileProjection.FromUser(user, profileImageUrl: null);
    }

    private async Task<User> LoadUser(Guid userId, CancellationToken cancellationToken)
    {
        return await _db.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new InvalidOperationException($"User {userId} was not found.");
    }
}
