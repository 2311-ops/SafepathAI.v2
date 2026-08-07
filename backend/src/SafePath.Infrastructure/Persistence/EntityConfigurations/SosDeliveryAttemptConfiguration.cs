using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class SosDeliveryAttemptConfiguration : IEntityTypeConfiguration<SosDeliveryAttempt>
{
    public void Configure(EntityTypeBuilder<SosDeliveryAttempt> builder)
    {
        builder.ToTable("SosDeliveryAttempts");
        builder.HasKey(a => a.Id);

        builder.Property(a => a.SosSessionId).IsRequired();
        builder.Property(a => a.Channel).IsRequired();
        builder.Property(a => a.Status).IsRequired();
        builder.Property(a => a.FailureReason).HasMaxLength(512);
        builder.Property(a => a.ProviderMessageId).HasMaxLength(128);

        builder.HasOne<SosSession>()
            .WithMany()
            .HasForeignKey(a => a.SosSessionId)
            .OnDelete(DeleteBehavior.Cascade);

        // WR-04: a single composite unique index across both RecipientUserId and
        // EmergencyContactId does not actually constrain SMS rows -- exactly one of the two is
        // always set (see SosDeliveryAttempt's doc comment), so the other is always NULL, and SQL
        // treats every NULL as distinct from every other NULL in a unique index. Two partial
        // (filtered) unique indexes -- one per recipient-identifying column, each only covering
        // the rows where that column is actually populated -- enforce "one row per
        // (session, recipient, channel)" for both guardian (RecipientUserId) and emergency-
        // contact (EmergencyContactId) delivery attempts.
        builder.HasIndex(a => new { a.SosSessionId, a.RecipientUserId, a.Channel })
            .IsUnique()
            .HasFilter("\"RecipientUserId\" IS NOT NULL");
        builder.HasIndex(a => new { a.SosSessionId, a.EmergencyContactId, a.Channel })
            .IsUnique()
            .HasFilter("\"EmergencyContactId\" IS NOT NULL");
    }
}
