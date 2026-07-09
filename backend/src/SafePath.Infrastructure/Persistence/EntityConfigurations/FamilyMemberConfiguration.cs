using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SafePath.Domain.Entities;

namespace SafePath.Infrastructure.Persistence.EntityConfigurations;

public class FamilyMemberConfiguration : IEntityTypeConfiguration<FamilyMember>
{
    public void Configure(EntityTypeBuilder<FamilyMember> builder)
    {
        builder.ToTable("FamilyMembers");
        builder.HasKey(m => m.Id);

        builder.Property(m => m.Role).HasConversion<string>().IsRequired();
        builder.Property(m => m.Permissions).HasConversion<string>().IsRequired();
        builder.Property(m => m.JoinedAt).IsRequired();
        builder.Property(m => m.IsActive).IsRequired();

        builder.HasOne<Family>()
            .WithMany()
            .HasForeignKey(m => m.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);

        // A user has at most one membership row per family; used by
        // FamilyAuthorizationService's membership lookup.
        builder.HasIndex(m => new { m.FamilyId, m.UserId }).IsUnique();
        builder.HasIndex(m => m.UserId)
            .IsUnique()
            .HasFilter("\"IsActive\" = TRUE");
    }
}
