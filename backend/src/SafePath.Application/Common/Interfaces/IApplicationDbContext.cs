using Microsoft.EntityFrameworkCore;
using SafePath.Domain.Entities;

namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Application-layer seam over the EF Core DbContext — implemented in Infrastructure by
/// ApplicationDbContext. Keeps Application free of any direct Infrastructure/Npgsql reference.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<User> Users { get; }
    DbSet<Family> Families { get; }
    DbSet<FamilyMember> FamilyMembers { get; }
    DbSet<FamilyInvitation> FamilyInvitations { get; }
    DbSet<LocationPing> LocationPings { get; }
    DbSet<SharingPreference> SharingPreferences { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
