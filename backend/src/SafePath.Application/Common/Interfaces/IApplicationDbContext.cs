using Microsoft.EntityFrameworkCore;
using SafePath.Domain.Entities;

namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Application-layer seam over the EF Core DbContext — implemented in Infrastructure by
/// ApplicationDbContext. Keeps Application free of any direct Infrastructure/Npgsql reference.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<Family> Families { get; }
    DbSet<FamilyMember> FamilyMembers { get; }
    DbSet<FamilyInvitation> FamilyInvitations { get; }
    DbSet<LocationPing> LocationPings { get; }
    DbSet<SharingPreference> SharingPreferences { get; }
    DbSet<SosSession> SosSessions { get; }
    DbSet<SosDeliveryAttempt> SosDeliveryAttempts { get; }
    DbSet<EmergencyContact> EmergencyContacts { get; }
    DbSet<UserDeviceToken> UserDeviceTokens { get; }
    DbSet<SafeZone> SafeZones { get; }
    DbSet<SafeZoneRecipient> SafeZoneRecipients { get; }
    DbSet<SafeZoneRegistration> SafeZoneRegistrations { get; }
    DbSet<GeofenceCandidate> GeofenceCandidates { get; }
    DbSet<GeofenceConfirmationCandidate> GeofenceConfirmationCandidates { get; }
    DbSet<SafeZoneRegistrationActivation> SafeZoneRegistrationActivations { get; }
    DbSet<GeofenceActivity> GeofenceActivities { get; }
    DbSet<GeofenceFeedItem> GeofenceFeedItems { get; }
    DbSet<GeofenceRoutineJob> GeofenceRoutineJobs { get; }
    DbSet<RecipientQuietHours> RecipientQuietHours { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
