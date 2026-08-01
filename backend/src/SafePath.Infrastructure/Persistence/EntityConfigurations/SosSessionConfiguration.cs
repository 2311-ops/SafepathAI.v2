using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class SosSessionConfiguration : IEntityTypeConfiguration<SosSession>
{
    public void Configure(EntityTypeBuilder<SosSession> builder)
    {
        builder.ToTable("SosSessions");
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).ValueGeneratedNever();

        builder.Property(s => s.FamilyId).IsRequired();
        builder.Property(s => s.TriggeredByUserId).IsRequired();
        builder.Property(s => s.Kind).IsRequired();
        builder.Property(s => s.Status).IsRequired();
        builder.Property(s => s.TriggeredAtUtc).IsRequired();
        builder.Property(s => s.ReceivedAtUtc).IsRequired();

        builder.HasOne<Family>()
            .WithMany()
            .HasForeignKey(s => s.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(s => s.TriggeredByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasIndex(s => new { s.FamilyId, s.TriggeredAtUtc });
    }
}
