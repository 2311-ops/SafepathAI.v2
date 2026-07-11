using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;

namespace SafePath.Application.Families;

public record UpdateMyRoleCommand(Guid UserId, Role Role, string? Email, string? FullName);

public class UpdateMyRoleCommandHandler : ICommandHandler<UpdateMyRoleCommand, GetMeResult>
{
    private readonly IApplicationDbContext _db;

    public UpdateMyRoleCommandHandler(IApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<GetMeResult> Handle(UpdateMyRoleCommand command, CancellationToken cancellationToken = default)
    {
        var user = await _db.Users.SingleOrDefaultAsync(u => u.Id == command.UserId, cancellationToken);
        if (user is null)
        {
            user = new User
            {
                Id = command.UserId,
                Email = command.Email ?? string.Empty,
                FullName = command.FullName ?? string.Empty,
                CreatedAt = DateTime.UtcNow,
            };
            _db.Users.Add(user);
        }

        user.Role = command.Role;
        if (!string.IsNullOrWhiteSpace(command.Email))
        {
            user.Email = command.Email;
        }
        if (!string.IsNullOrWhiteSpace(command.FullName))
        {
            user.FullName = command.FullName;
        }

        await _db.SaveChangesAsync(cancellationToken);

        return new GetMeResult(user.Id, user.Role, user.Email, user.FullName);
    }
}
