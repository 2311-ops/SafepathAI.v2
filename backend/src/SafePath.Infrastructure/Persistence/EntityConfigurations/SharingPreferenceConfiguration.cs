using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class SharingPreferenceConfiguration : IEntityTypeConfiguration<SharingPreference>
{
    public void Configure(EntityTypeBuilder<SharingPreference> builder)
    {
        builder.ToTable("SharingPreferences");
        builder.HasKey(p => p.Id);

        builder.Property(p => p.DataType).HasConversion<string>().IsRequired();
        builder.Property(p => p.IsEnabled).IsRequired();

        builder.HasOne<Family>()
            .WithMany()
            .HasForeignKey(p => p.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne<FamilyMember>()
            .WithMany()
            .HasForeignKey(p => p.RecipientMemberId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(p => new { p.OwnerUserId, p.DataType });
        builder.HasIndex(p => new { p.FamilyId, p.OwnerUserId });
    }
}
