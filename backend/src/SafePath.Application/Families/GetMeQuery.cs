using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record GetMeQuery(Guid UserId);

public record GetMeResult(Guid UserId, Role? Role, string? Email, string? FullName);

public class GetMeQueryHandler : ICommandHandler<GetMeQuery, GetMeResult>
{
    private readonly IApplicationDbContext _db;

    public GetMeQueryHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<GetMeResult> Handle(GetMeQuery command, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.SingleOrDefaultAsync(u => u.Id == command.UserId, cancellationToken);
        return user is null
            ? new GetMeResult(command.UserId, null, null, null)
            : new GetMeResult(user.Id, user.Role, user.Email, user.FullName);
    }
}
