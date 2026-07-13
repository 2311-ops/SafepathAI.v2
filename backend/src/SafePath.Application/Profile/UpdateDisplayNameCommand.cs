using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Entities;

namespace SafePath.Application.Profile;

public record UpdateDisplayNameCommand(Guid CallerUserId, string DisplayName);

public class UpdateDisplayNameCommandHandler : ICommandHandler<UpdateDisplayNameCommand, GetMeResult>
{
    private const int MaxDisplayNameLength = 80;

    private readonly IApplicationDbContext _db;

    public UpdateDisplayNameCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<GetMeResult> Handle(UpdateDisplayNameCommand command, CancellationToken cancellationToken = default)
    {
        var displayName = NormalizeDisplayName(command.DisplayName);
        var user = await LoadUser(command.CallerUserId, cancellationToken);

        user.DisplayName = displayName;
        user.ProfileUpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(cancellationToken);

        return ProfileProjection.FromUser(user, profileImageUrl: null);
    }

    private async Task<User> LoadUser(Guid userId, CancellationToken cancellationToken)
    {
        return await _db.Users.SingleOrDefaultAsync(u => u.Id == userId, cancellationToken)
            ?? throw new InvalidOperationException($"User {userId} was not found.");
    }

    private static string NormalizeDisplayName(string displayName)
    {
        var trimmed = displayName.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            throw new ArgumentException("Display name is required.", nameof(displayName));
        }

        if (trimmed.Length > MaxDisplayNameLength)
        {
            throw new ArgumentException($"Display name must be {MaxDisplayNameLength} characters or fewer.", nameof(displayName));
        }

        return trimmed;
    }
}
