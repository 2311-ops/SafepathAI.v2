using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Infrastructure.Persistence.EntityConfigurations;

namespace SafePath.Infrastructure.Persistence;

public class ApplicationDbContext : DbContext, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Family> Families => Set<Family>();
    public DbSet<FamilyMember> FamilyMembers => Set<FamilyMember>();
    public DbSet<FamilyInvitation> FamilyInvitations => Set<FamilyInvitation>();
    public DbSet<LocationPing> LocationPings => Set<LocationPing>();
    public DbSet<SharingPreference> SharingPreferences => Set<SharingPreference>();
    public DbSet<SosSession> SosSessions => Set<SosSession>();
    public DbSet<SosDeliveryAttempt> SosDeliveryAttempts => Set<SosDeliveryAttempt>();
    public DbSet<EmergencyContact> EmergencyContacts => Set<EmergencyContact>();
    public DbSet<UserDeviceToken> UserDeviceTokens => Set<UserDeviceToken>();
    public DbSet<SafeZone> SafeZones => Set<SafeZone>();
    public DbSet<SafeZoneRecipient> SafeZoneRecipients => Set<SafeZoneRecipient>();
    public DbSet<SafeZoneRegistration> SafeZoneRegistrations => Set<SafeZoneRegistration>();
    public DbSet<GeofenceCandidate> GeofenceCandidates => Set<GeofenceCandidate>();
    public DbSet<GeofenceConfirmationCandidate> GeofenceConfirmationCandidates => Set<GeofenceConfirmationCandidate>();
    public DbSet<SafeZoneRegistrationActivation> SafeZoneRegistrationActivations => Set<SafeZoneRegistrationActivation>();
    public DbSet<GeofenceActivity> GeofenceActivities => Set<GeofenceActivity>();
    public DbSet<GeofenceFeedItem> GeofenceFeedItems => Set<GeofenceFeedItem>();
    public DbSet<GeofenceRoutineJob> GeofenceRoutineJobs => Set<GeofenceRoutineJob>();
    public DbSet<RecipientQuietHours> RecipientQuietHours => Set<RecipientQuietHours>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfiguration(new UserConfiguration());
        modelBuilder.ApplyConfiguration(new FamilyConfiguration());
        modelBuilder.ApplyConfiguration(new FamilyMemberConfiguration());
        modelBuilder.ApplyConfiguration(new FamilyInvitationConfiguration());
        modelBuilder.ApplyConfiguration(new LocationPingConfiguration());
        modelBuilder.ApplyConfiguration(new SharingPreferenceConfiguration());
        modelBuilder.ApplyConfiguration(new SosSessionConfiguration());
        modelBuilder.ApplyConfiguration(new SosDeliveryAttemptConfiguration());
        modelBuilder.ApplyConfiguration(new EmergencyContactConfiguration());
        modelBuilder.ApplyConfiguration(new UserDeviceTokenConfiguration());
        GeofencingConfiguration.Configure(modelBuilder);

        base.OnModelCreating(modelBuilder);
    }
}
