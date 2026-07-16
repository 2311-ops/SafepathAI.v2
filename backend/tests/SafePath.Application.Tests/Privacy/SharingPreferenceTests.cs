using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Privacy;

public class SharingPreferenceTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task FilterRecipients_WithNoRows_DefaultsToSharingWithActiveFamilyCandidates()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        var service = new SharingAuthorizationService(db);

        var result = await service.FilterRecipients(
            seed.OwnerUserId,
            seed.FamilyId,
            SharedDataType.LiveLocation,
            [seed.OwnerUserId, seed.RecipientUserId],
            CancellationToken.None);

        Assert.Contains(seed.OwnerUserId, result);
        Assert.Contains(seed.RecipientUserId, result);
    }

    [Fact]
    public async Task FilterRecipients_ExplicitDisabledRow_RemovesThatRecipient()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = seed.FamilyId,
            OwnerUserId = seed.OwnerUserId,
            RecipientMemberId = seed.RecipientMemberId,
            DataType = SharedDataType.LiveLocation,
            IsEnabled = false,
        });
        await db.SaveChangesAsync();
        var service = new SharingAuthorizationService(db);

        var result = await service.FilterRecipients(
            seed.OwnerUserId,
            seed.FamilyId,
            SharedDataType.LiveLocation,
            [seed.OwnerUserId, seed.RecipientUserId],
            CancellationToken.None);

        Assert.Contains(seed.OwnerUserId, result);
        Assert.DoesNotContain(seed.RecipientUserId, result);
    }

    [Fact]
    public async Task FilterRecipients_ExplicitExpiredRow_RemovesRecipientEvenWhenEnabled()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.SharingPreferences.Add(new SharingPreference
        {
            Id = Guid.NewGuid(),
            FamilyId = seed.FamilyId,
            OwnerUserId = seed.OwnerUserId,
            RecipientMemberId = seed.RecipientMemberId,
            DataType = SharedDataType.LiveLocation,
            IsEnabled = true,
            ExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1),
        });
        await db.SaveChangesAsync();
        var service = new SharingAuthorizationService(db);

        var result = await service.FilterRecipients(
            seed.OwnerUserId,
            seed.FamilyId,
            SharedDataType.LiveLocation,
            [seed.OwnerUserId, seed.RecipientUserId],
            CancellationToken.None);

        Assert.Contains(seed.OwnerUserId, result);
        Assert.DoesNotContain(seed.RecipientUserId, result);
    }

    [Fact]
    public async Task FilterRecipients_DefaultRowCanBeOverriddenPerRecipient()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db);
        db.SharingPreferences.AddRange(
            new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = seed.FamilyId,
                OwnerUserId = seed.OwnerUserId,
                RecipientMemberId = null,
                DataType = SharedDataType.LiveLocation,
                IsEnabled = false,
            },
            new SharingPreference
            {
                Id = Guid.NewGuid(),
                FamilyId = seed.FamilyId,
                OwnerUserId = seed.OwnerUserId,
                RecipientMemberId = seed.RecipientMemberId,
                DataType = SharedDataType.LiveLocation,
                IsEnabled = true,
            });
        await db.SaveChangesAsync();
        var service = new SharingAuthorizationService(db);

        var result = await service.FilterRecipients(
            seed.OwnerUserId,
            seed.FamilyId,
            SharedDataType.LiveLocation,
            [seed.OwnerUserId, seed.RecipientUserId],
            CancellationToken.None);

        // Owners always receive their own data, mirroring CanView's self-bypass —
        // a disabled default preference must not cut off a user's own live feed.
        Assert.Contains(seed.OwnerUserId, result);
        Assert.Contains(seed.RecipientUserId, result);
    }

    [Fact]
    public async Task FilterRecipients_DoesNotDependOnFamilyMemberPermissionLevel()
    {
        await using var db = _factory.CreateContext();
        var seed = await SeedFamily(db, recipientPermissions: PermissionLevel.ViewOnly);
        var service = new SharingAuthorizationService(db);

        var result = await service.FilterRecipients(
            seed.OwnerUserId,
            seed.FamilyId,
            SharedDataType.LiveLocation,
            [seed.RecipientUserId],
            CancellationToken.None);

        Assert.Equal([seed.RecipientUserId], result);
    }

    private static async Task<SharingSeed> SeedFamily(
        ApplicationDbContext db,
        PermissionLevel recipientPermissions = PermissionLevel.FullLocation)
    {
        var familyId = Guid.NewGuid();
        var ownerUserId = Guid.NewGuid();
        var recipientUserId = Guid.NewGuid();
        var ownerMemberId = Guid.NewGuid();
        var recipientMemberId = Guid.NewGuid();

        db.Users.AddRange(
            new User { Id = ownerUserId, Email = "owner@example.com", FullName = "Owner", Role = Role.Member, CreatedAt = DateTime.UtcNow },
            new User { Id = recipientUserId, Email = "recipient@example.com", FullName = "Recipient", Role = Role.Guardian, CreatedAt = DateTime.UtcNow });
        db.Families.Add(new Family { Id = familyId, Name = "Privacy Family", CreatedByUserId = recipientUserId, CreatedAt = DateTime.UtcNow });
        db.FamilyMembers.AddRange(
            new FamilyMember
            {
                Id = ownerMemberId,
                FamilyId = familyId,
                UserId = ownerUserId,
                Role = Role.Member,
                Permissions = PermissionLevel.FullLocation,
                JoinedAt = DateTime.UtcNow.AddMinutes(-2),
                IsActive = true,
            },
            new FamilyMember
            {
                Id = recipientMemberId,
                FamilyId = familyId,
                UserId = recipientUserId,
                Role = Role.Guardian,
                Permissions = recipientPermissions,
                JoinedAt = DateTime.UtcNow.AddMinutes(-1),
                IsActive = true,
            });

        await db.SaveChangesAsync();
        return new SharingSeed(familyId, ownerUserId, recipientUserId, ownerMemberId, recipientMemberId);
    }

    public void Dispose() => _factory.Dispose();

    private sealed record SharingSeed(
        Guid FamilyId,
        Guid OwnerUserId,
        Guid RecipientUserId,
        Guid OwnerMemberId,
        Guid RecipientMemberId);
}
