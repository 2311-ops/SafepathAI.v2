using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Privacy;

public record DeleteMyDataCommand(Guid CallerUserId);

public class DeleteMyDataCommandHandler : ICommandHandler<DeleteMyDataCommand, DeleteMyDataResult>
{
    private readonly IApplicationDbContext _db;

    public DeleteMyDataCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<DeleteMyDataResult> Handle(DeleteMyDataCommand command, CancellationToken cancellationToken = default)
    {
        var pings = await _db.LocationPings
            .Where(p => p.UserId == command.CallerUserId)
            .ToListAsync(cancellationToken);

        _db.LocationPings.RemoveRange(pings);
        await _db.SaveChangesAsync(cancellationToken);

        return new DeleteMyDataResult(pings.Count);
    }
}
