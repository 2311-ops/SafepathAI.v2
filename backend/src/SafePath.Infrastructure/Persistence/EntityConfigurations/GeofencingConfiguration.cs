using Microsoft.EntityFrameworkCore;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public static class GeofencingConfiguration
{
    public static void Configure(ModelBuilder modelBuilder)
    {
        ConfigureSafeZones(modelBuilder);
        ConfigureConfirmationCandidates(modelBuilder);
        ConfigureRegistrationActivations(modelBuilder);
        ConfigureActivities(modelBuilder);
        ConfigureFeedItems(modelBuilder);
        ConfigureRoutineJobs(modelBuilder);
        ConfigureQuietHours(modelBuilder);
    }

    private static void ConfigureSafeZones(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SafeZone>(builder =>
        {
            builder.ToTable("SafeZones", table =>
            {
                table.HasCheckConstraint("CK_SafeZones_Category", "\"Category\" BETWEEN 0 AND 4");
                table.HasCheckConstraint("CK_SafeZones_Sensitivity", "\"Sensitivity\" BETWEEN 0 AND 2");
            });
            builder.HasKey(zone => zone.Id);
            builder.Property(zone => zone.Id).ValueGeneratedNever();
            builder.Property(zone => zone.FamilyId).IsRequired();
            builder.Property(zone => zone.AssignedMemberUserId).IsRequired();
            builder.Property(zone => zone.CreatedByUserId).IsRequired();
            builder.Property(zone => zone.Category).HasConversion<int>().IsRequired();
            builder.Property(zone => zone.Latitude).IsRequired();
            builder.Property(zone => zone.Longitude).IsRequired();
            builder.Property(zone => zone.RadiusMeters).IsRequired();
            builder.Property(zone => zone.Sensitivity).HasConversion<int>().IsRequired();
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
            builder.ToTable("SafeZoneRegistrations", table =>
                table.HasCheckConstraint("CK_SafeZoneRegistrations_Generation", "\"Generation\" > 0"));
            builder.HasKey(registration => registration.Id);
            builder.Property(registration => registration.Id).ValueGeneratedNever();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(registration => registration.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(registration => registration.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(registration => new { registration.SafeZoneId, registration.Generation }).IsUnique();
        });

        modelBuilder.Entity<GeofenceCandidate>(builder =>
        {
            builder.ToTable("GeofenceCandidates", table =>
            {
                table.HasCheckConstraint("CK_GeofenceCandidates_Generation", "\"RegistrationGeneration\" > 0");
                table.HasCheckConstraint("CK_GeofenceCandidates_Transition", "\"Transition\" BETWEEN 0 AND 1");
            });
            builder.HasKey(candidate => candidate.Id);
            builder.Property(candidate => candidate.Id).ValueGeneratedNever();
            builder.Property(candidate => candidate.EventId).IsRequired();
            builder.Property(candidate => candidate.Transition).HasConversion<int>().IsRequired();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(candidate => candidate.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(candidate => candidate.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(candidate => candidate.EventId).IsUnique();
            builder.HasIndex(candidate => new { candidate.SafeZoneId, candidate.MemberUserId, candidate.OccurredAtUtc });
        });
    }

    private static void ConfigureConfirmationCandidates(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GeofenceConfirmationCandidate>(builder =>
        {
            builder.ToTable("GeofenceConfirmationCandidates", table =>
            {
                table.HasCheckConstraint("CK_GeofenceConfirmationCandidates_Generation", "\"RegistrationGeneration\" > 0");
                table.HasCheckConstraint("CK_GeofenceConfirmationCandidates_Transition", "\"IntendedTransition\" BETWEEN 0 AND 1");
                table.HasCheckConstraint("CK_GeofenceConfirmationCandidates_State", "\"State\" BETWEEN 0 AND 3");
            });
            builder.HasKey(candidate => candidate.Id);
            builder.Property(candidate => candidate.Id).ValueGeneratedNever();
            builder.Property(candidate => candidate.IntendedTransition).HasConversion<int>().IsRequired();
            builder.Property(candidate => candidate.State).HasConversion<int>().IsRequired();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(candidate => candidate.SafeZoneId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(candidate => candidate.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(candidate => new { candidate.SafeZoneId, candidate.MemberUserId, candidate.RegistrationGeneration, candidate.IntendedTransition }).IsUnique();
            builder.HasIndex(candidate => new { candidate.State, candidate.LastObservedAtUtc });
        });
    }

    private static void ConfigureRegistrationActivations(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SafeZoneRegistrationActivation>(builder =>
        {
            builder.ToTable("SafeZoneRegistrationActivations", table =>
                table.HasCheckConstraint("CK_SafeZoneRegistrationActivations_State", "\"State\" BETWEEN 0 AND 3"));
            builder.HasKey(activation => activation.Id);
            builder.Property(activation => activation.Id).ValueGeneratedNever();
            builder.Property(activation => activation.State).HasConversion<int>().IsRequired();
            builder.Property(activation => activation.FailureReason).HasMaxLength(512);
            builder.HasOne<SafeZoneRegistration>().WithMany().HasForeignKey(activation => activation.SafeZoneRegistrationId).OnDelete(DeleteBehavior.Cascade);
            builder.HasIndex(activation => activation.SafeZoneRegistrationId).IsUnique();
            builder.HasIndex(activation => new { activation.State, activation.StateChangedAtUtc });
        });
    }

    private static void ConfigureActivities(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GeofenceActivity>(builder =>
        {
            builder.ToTable("GeofenceActivities", table =>
                table.HasCheckConstraint("CK_GeofenceActivities_Transition", "\"Transition\" BETWEEN 0 AND 1"));
            builder.HasKey(activity => activity.Id);
            builder.Property(activity => activity.Id).ValueGeneratedNever();
            builder.Property(activity => activity.SafeZoneDisplayName).IsRequired().HasMaxLength(160);
            builder.Property(activity => activity.Transition).HasConversion<int>().IsRequired();
            builder.HasOne<SafeZone>().WithMany().HasForeignKey(activity => activity.SafeZoneId).OnDelete(DeleteBehavior.SetNull);
            builder.HasOne<User>().WithMany().HasForeignKey(activity => activity.MemberUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(activity => new { activity.MemberUserId, activity.OccurredAtUtc });
            builder.HasIndex(activity => activity.RetainUntilUtc);
            builder.HasIndex(activity => activity.VisitId);
        });
    }

    private static void ConfigureFeedItems(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GeofenceFeedItem>(builder =>
        {
            builder.ToTable("GeofenceFeedItems");
            builder.HasKey(item => item.Id);
            builder.Property(item => item.Id).ValueGeneratedNever();
            builder.HasOne<GeofenceActivity>().WithMany().HasForeignKey(item => item.ActivityId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(item => item.RecipientUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(item => new { item.ActivityId, item.RecipientUserId }).IsUnique();
            builder.HasIndex(item => new { item.RecipientUserId, item.CreatedAtUtc });
            builder.HasIndex(item => item.ExpiresAtUtc);
        });
    }

    private static void ConfigureRoutineJobs(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<GeofenceRoutineJob>(builder =>
        {
            builder.ToTable("GeofenceRoutineJobs", table =>
                table.HasCheckConstraint("CK_GeofenceRoutineJobs_State", "\"State\" BETWEEN 0 AND 5"));
            builder.HasKey(job => job.Id);
            builder.Property(job => job.Id).ValueGeneratedNever();
            builder.Property(job => job.State).HasConversion<int>().IsRequired();
            builder.Property(job => job.LastFailureReason).HasMaxLength(512);
            builder.HasOne<GeofenceFeedItem>().WithMany().HasForeignKey(job => job.FeedItemId).OnDelete(DeleteBehavior.Cascade);
            builder.HasOne<User>().WithMany().HasForeignKey(job => job.RecipientUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(job => job.FeedItemId).IsUnique();
            builder.HasIndex(job => new { job.State, job.NextAttemptAtUtc });
            builder.HasIndex(job => job.ExpiresAtUtc);
        });
    }

    private static void ConfigureQuietHours(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<RecipientQuietHours>(builder =>
        {
            builder.ToTable("RecipientQuietHours");
            builder.HasKey(setting => setting.Id);
            builder.Property(setting => setting.Id).ValueGeneratedNever();
            builder.Property(setting => setting.IsEnabled).HasDefaultValue(false).IsRequired();
            builder.Property(setting => setting.LocalStart).IsRequired();
            builder.Property(setting => setting.LocalEnd).IsRequired();
            builder.Property(setting => setting.TimeZoneId).IsRequired().HasMaxLength(128);
            builder.HasOne<User>().WithMany().HasForeignKey(setting => setting.RecipientUserId).OnDelete(DeleteBehavior.Restrict);
            builder.HasIndex(setting => setting.RecipientUserId).IsUnique();
        });
    }
}
