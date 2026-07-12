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
    private readonly ICommandHandler<GetLocationHistoryQuery, LocationHistoryDto> _getLocationHistory;
    private readonly ICommandHandler<GetTravelStatsQuery, TravelStatsDto> _getTravelStats;
    private readonly ICurrentUserService _currentUser;

    public LocationController(
        ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>> getLiveLocations,
        ICommandHandler<GetLocationHistoryQuery, LocationHistoryDto> getLocationHistory,
        ICommandHandler<GetTravelStatsQuery, TravelStatsDto> getTravelStats,
        ICurrentUserService currentUser)
    {
        _getLiveLocations = getLiveLocations;
        _getLocationHistory = getLocationHistory;
        _getTravelStats = getTravelStats;
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

    /// <summary>Returns the caller-authorized route polyline and detected stops for a family member.</summary>
    [HttpGet("families/{familyId:guid}/members/{targetUserId:guid}/history")]
    public async Task<ActionResult<LocationHistoryDto>> GetHistory(
        Guid familyId,
        Guid targetUserId,
        [FromQuery] DateTime from,
        [FromQuery] DateTime to,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var history = await _getLocationHistory.Handle(
                new GetLocationHistoryQuery(userId, familyId, targetUserId, from, to),
                cancellationToken);
            return Ok(history);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>Returns distance, time-away, and stop-count stats for a caller-authorized history range.</summary>
    [HttpGet("families/{familyId:guid}/members/{targetUserId:guid}/travel-stats")]
    public async Task<ActionResult<TravelStatsDto>> GetTravelStats(
        Guid familyId,
        Guid targetUserId,
        [FromQuery] DateTime from,
        [FromQuery] DateTime to,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var stats = await _getTravelStats.Handle(
                new GetTravelStatsQuery(userId, familyId, targetUserId, from, to),
                cancellationToken);
            return Ok(stats);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }
}
