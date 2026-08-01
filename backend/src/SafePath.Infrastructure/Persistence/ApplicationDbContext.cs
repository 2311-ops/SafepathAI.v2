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

        base.OnModelCreating(modelBuilder);
    }
}
