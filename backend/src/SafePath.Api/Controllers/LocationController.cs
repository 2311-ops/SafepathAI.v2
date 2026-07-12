using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Location;

namespace SafePath.Api.Controllers;

[ApiController]
[Authorize]
public class LocationController : ControllerBase
{
    private readonly ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>> _getLiveLocations;
    private readonly ICurrentUserService _currentUser;

    public LocationController(
        ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>> getLiveLocations,
        ICurrentUserService currentUser)
    {
        _getLiveLocations = getLiveLocations;
        _currentUser = currentUser;
    }

    /// <summary>Returns the caller's family-scoped live-location initial load (IDOR-gated).</summary>
    [HttpGet("families/{familyId:guid}/live-locations")]
    public async Task<ActionResult<IReadOnlyList<MemberLiveLocationDto>>> GetLiveLocations(
        Guid familyId,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var locations = await _getLiveLocations.Handle(new GetLiveLocationsQuery(userId, familyId), cancellationToken);
            return Ok(locations);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }
}
