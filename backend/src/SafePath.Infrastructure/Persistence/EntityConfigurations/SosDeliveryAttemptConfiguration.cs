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

        builder.HasIndex(a => new { a.SosSessionId, a.RecipientUserId, a.EmergencyContactId, a.Channel })
            .IsUnique();
    }
}
