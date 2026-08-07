using Microsoft.EntityFrameworkCore;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Application.Sos;

public record GetSosSessionQuery(Guid CallerUserId, Guid SosSessionId);

public record GetSosSessionResult(SosSessionDto? Session);

/// <summary>
/// Returns the current status of an SOS session. Re-verifies the caller's active membership in
/// the session's family before returning any delivery state (threat T-03-04) — an SOS session
/// id is not itself proof of authorization to view it.
/// </summary>
public class GetSosSessionQueryHandler : ICommandHandler<GetSosSessionQuery, GetSosSessionResult>
{
    private readonly IApplicationDbContext _db;
    private readonly IFamilyAuthorizationService _authorization;

    public GetSosSessionQueryHandler(IApplicationDbContext db, IFamilyAuthorizationService authorization)
    {
        _db = db;
        _authorization = authorization;
    }

    public async Task<GetSosSessionResult> Handle(GetSosSessionQuery query, CancellationToken cancellationToken = default)
    {
        var session = await _db.SosSessions
            .SingleOrDefaultAsync(s => s.Id == query.SosSessionId, cancellationToken);

        if (session is null)
        {
            return new GetSosSessionResult(null);
        }

        await _authorization.RequireMembership(query.CallerUserId, session.FamilyId, cancellationToken);

        var dto = await SosSessionProjection.ProjectAsync(_db, session, query.CallerUserId, cancellationToken);
        return new GetSosSessionResult(dto);
    }
}
