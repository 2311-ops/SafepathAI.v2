using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

/// <summary>Creates a new family circle and inserts the caller as its first Guardian (FAM-01).</summary>
public record CreateFamilyCommand(Guid UserId, string Name);

public class CreateFamilyCommandHandler : ICommandHandler<CreateFamilyCommand, Guid>
{
    private readonly IApplicationDbContext _db;

    public CreateFamilyCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<Guid> Handle(CreateFamilyCommand command, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(command.Name))
        {
            throw new ArgumentException("Family name is required.", nameof(command));
        }

        var family = new Family
        {
            Id = Guid.NewGuid(),
            Name = command.Name,
            CreatedByUserId = command.UserId,
            CreatedAt = DateTime.UtcNow,
        };

        var membership = new FamilyMember
        {
            Id = Guid.NewGuid(),
            FamilyId = family.Id,
            UserId = command.UserId,
            Role = Role.Guardian,
            Permissions = PermissionLevel.FullLocation,
            JoinedAt = DateTime.UtcNow,
            IsActive = true,
        };

        _db.Families.Add(family);
        _db.FamilyMembers.Add(membership);
        await _db.SaveChangesAsync(cancellationToken);

        return family.Id;
    }
}
