using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class EmergencyContactConfiguration : IEntityTypeConfiguration<EmergencyContact>
{
    public void Configure(EntityTypeBuilder<EmergencyContact> builder)
    {
        builder.ToTable("EmergencyContacts");
        builder.HasKey(c => c.Id);

        builder.Property(c => c.DisplayName).IsRequired().HasMaxLength(120);
        builder.Property(c => c.PhoneNumberE164).IsRequired().HasMaxLength(20);

        builder.HasOne<User>()
            .WithMany()
            .HasForeignKey(c => c.OwnerUserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasIndex(c => new { c.OwnerUserId, c.IsActive });
    }
}
