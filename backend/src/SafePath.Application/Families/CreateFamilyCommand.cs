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

    public Task<Guid> Handle(CreateFamilyCommand command, CancellationToken cancellationToken = default)
    {
        // RED: implementation intentionally not yet written — see 01-05 TDD RED/GREEN cycle.
        throw new NotImplementedException();
    }
}
