using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class FamilyInvitationConfiguration : IEntityTypeConfiguration<FamilyInvitation>
{
    public void Configure(EntityTypeBuilder<FamilyInvitation> builder)
    {
        builder.ToTable("FamilyInvitations");
        builder.HasKey(i => i.Id);

        builder.Property(i => i.Code).IsRequired().HasMaxLength(16);
        builder.HasIndex(i => i.Code).IsUnique();

        builder.Property(i => i.LinkToken).IsRequired().HasMaxLength(64);
        builder.HasIndex(i => i.LinkToken).IsUnique();

        builder.Property(i => i.InviteeLabel).HasMaxLength(200);
        builder.Property(i => i.InviteeEmail).HasMaxLength(320);
        builder.Property(i => i.Status).HasConversion<string>().IsRequired();
        builder.Property(i => i.ExpiresAt).IsRequired();
    }
}
