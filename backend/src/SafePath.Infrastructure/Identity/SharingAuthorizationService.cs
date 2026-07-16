using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Infrastructure.Identity;

public class SharingAuthorizationService : ISharingAuthorizationService
{
    private readonly IApplicationDbContext _db;

    public SharingAuthorizationService(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyCollection<Guid>> FilterRecipients(
        Guid ownerUserId,
        Guid familyId,
        SharedDataType dataType,
        IReadOnlyCollection<Guid> candidateRecipientUserIds,
        CancellationToken cancellationToken = default)
    {
        if (candidateRecipientUserIds.Count == 0)
        {
            return [];
        }

        var candidateSet = candidateRecipientUserIds.ToHashSet();
        var candidateMembers = await _db.FamilyMembers
            .Where(m => m.FamilyId == familyId && m.IsActive && candidateSet.Contains(m.UserId))
            .Select(m => new { m.Id, m.UserId })
            .ToListAsync(cancellationToken);

        var preferences = await _db.SharingPreferences
            .Where(p => p.FamilyId == familyId && p.OwnerUserId == ownerUserId && p.DataType == dataType)
            .ToListAsync(cancellationToken);

        var defaultPreference = preferences.FirstOrDefault(p => p.RecipientMemberId == null);
        var explicitPreferences = preferences
            .Where(p => p.RecipientMemberId is not null)
            .GroupBy(p => p.RecipientMemberId!.Value)
            .ToDictionary(g => g.Key, g => g.First());

        var now = DateTime.UtcNow;
        var allowed = new List<Guid>(candidateMembers.Count);

        foreach (var member in candidateMembers)
        {
            if (member.UserId == ownerUserId)
            {
                // Owners always see/receive their own data, mirroring CanView's self-bypass.
                allowed.Add(member.UserId);
                continue;
            }

            var preference = explicitPreferences.TryGetValue(member.Id, out var explicitPreference)
                ? explicitPreference
                : defaultPreference;

            if (preference is null || IsCurrentlyEnabled(preference, now))
            {
                allowed.Add(member.UserId);
            }
        }

        return allowed;
    }

    public async Task<bool> CanView(
        Guid viewerUserId,
        Guid ownerUserId,
        Guid familyId,
        SharedDataType dataType,
        CancellationToken cancellationToken = default)
    {
        if (viewerUserId == ownerUserId)
        {
            return true;
        }

        var allowed = await FilterRecipients(
            ownerUserId,
            familyId,
            dataType,
            [viewerUserId],
            cancellationToken);

        return allowed.Contains(viewerUserId);
    }

    private static bool IsCurrentlyEnabled(SharingPreference preference, DateTime nowUtc) =>
        preference.IsEnabled && (preference.ExpiresAtUtc is null || preference.ExpiresAtUtc > nowUtc);
}
