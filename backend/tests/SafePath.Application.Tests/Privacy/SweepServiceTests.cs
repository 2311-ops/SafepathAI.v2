using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

namespace SafePath.Application.Tests.Privacy;

public class SweepServiceTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task SweepExpired_DisablesOnlyExpiredEnabledPreferences()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        var expiredEnabled = await SeedPreference(db, expiresAtUtc: now.AddMinutes(-1), isEnabled: true);
        var unexpiredEnabled = await SeedPreference(db, expiresAtUtc: now.AddMinutes(5), isEnabled: true);
        var noExpiryEnabled = await SeedPreference(db, expiresAtUtc: null, isEnabled: true);
        var expiredAlreadyDisabled = await SeedPreference(db, expiresAtUtc: now.AddMinutes(-5), isEnabled: false);

        var changed = await SharingPreferenceSweepService.SweepExpired(db, now, CancellationToken.None);

        Assert.Equal(1, changed);
        Assert.False(db.SharingPreferences.Single(p => p.Id == expiredEnabled).IsEnabled);
        Assert.True(db.SharingPreferences.Single(p => p.Id == unexpiredEnabled).IsEnabled);
        Assert.True(db.SharingPreferences.Single(p => p.Id == noExpiryEnabled).IsEnabled);
        Assert.False(db.SharingPreferences.Single(p => p.Id == expiredAlreadyDisabled).IsEnabled);
    }

    [Fact]
    public async Task SweepExpired_IsIdempotent()
    {
        await using var db = _factory.CreateContext();
        var now = DateTime.UtcNow;
        await SeedPreference(db, expiresAtUtc: now.AddSeconds(-1), isEnabled: true);

        var first = await SharingPreferenceSweepService.SweepExpired(db, now, CancellationToken.None);
        var second = await SharingPreferenceSweepService.SweepExpired(db, now, CancellationToken.None);

        Assert.Equal(1, first);
        Assert.Equal(0, second);
        Assert.False(db.SharingPreferences.Single().IsEnabled);
    }

    private static async Task<Guid> SeedPreference(
        ApplicationDbContext db,
        DateTime? expiresAtUtc,
        bool isEnabled)
    {
        var familyId = Guid.NewGuid();
        var ownerUserId = Guid.NewGuid();
        var recipientUserId = Guid.NewGuid();
        var recipientMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = ownerUserId, Email = $"{ownerUserId:N}@example.com", FullName = "Owner", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = recipientUserId, Email = $"{recipientUserId:N}@example.com", FullName = "Recipient", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Sweep Family", CreatedByUserId = recipientUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.Add(new FamilyMember
        {
            Id = recipientMemberId,
            FamilyId = familyId,
            UserId = recipientUserId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        });
        var preference = new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = familyId,
            OwnerUserId = ownerUserId,
            RecipientMemberId = recipientMemberId,
            DataType = SharedDataType.LiveLocation,
            IsEnabled = isEnabled,
            ExpiresAtUtc = expiresAtUtc,
        };
        db.SharingPreferences.Add(preference);
        await db.SaveChangesAsync();

        return preference.Id;
    }

    public void Dispose() => _factory.Dispose();
}
