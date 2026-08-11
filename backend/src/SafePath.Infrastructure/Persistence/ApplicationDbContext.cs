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

        modelBuilder.Entity<SafeZone>(builder =>
        {
            builder.ToTable("SafeZones");
            builder.HasKey(zone => zone.Id);
            builder.Property(zone => zone.Id).ValueGeneratedNever();
            builder.Property(zone => zone.FamilyId).IsRequired();
            builder.Property(zone => zone.AssignedMemberUserId).IsRequired();
            builder.Property(zone => zone.CreatedByUserId).IsRequired();
            builder.Property(zone => zone.Category).IsRequired();
            builder.Property(zone => zone.Latitude).IsRequired();
            builder.Property(zone => zone.Longitude).IsRequired();
            builder.Property(zone => zone.RadiusMeters).IsRequired();
            builder.Property(zone => zone.Sensitivity).IsRequired();
            builder.Property(zone => zone.CreatedAtUtc).IsRequired();
            builder.HasOne<Family>().WithMany().HasForeignKey(zone => zone.FamilyId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(zone => zone.AssignedMemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasOne<User>().WithMany().HasForeignKey(zone => zone.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(zone => new { zone.FamilyId, zone.AssignedMemberUserId, zone.IsActive });
        });
        modelBuilder.Entity<SafeZoneRecipient>(builder =>
        {
            builder.ToTable("SafeZoneRecipients");
            builder.HasKey(recipient => new { recipient.SafeZoneId, recipient.RecipientUserId });
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(recipient => recipient.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(recipient => recipient.RecipientUserId).OnDelete(DeleteBehavior.Restrict);
        });
        modelBuilder.Entity<SafeZoneRegistration>(builder =>
        {
            builder.ToTable("SafeZoneRegistrations");
            builder.HasKey(registration => registration.Id);
            builder.Property(registration => registration.Id).ValueGeneratedNever();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(registration => registration.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(registration => registration.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(registration => new { registration.SafeZoneId, registration.Generation }).IsUnique();
        });
        modelBuilder.Entity<GeofenceCandidate>(builder =>
        {
            builder.ToTable("GeofenceCandidates");
            builder.HasKey(candidate => candidate.Id);
            builder.Property(candidate => candidate.Id).ValueGeneratedNever();
            builder.Property(candidate => candidate.EventId).IsRequired();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(candidate => candidate.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(candidate => candidate.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(candidate => candidate.EventId).IsUnique();
            builder.HasIndex(candidate => new { candidate.SafeZoneId, candidate.MemberUserId, candidate.OccurredAtUtc });
        });

        base.OnModelCreating(modelBuilder);
    }
}
