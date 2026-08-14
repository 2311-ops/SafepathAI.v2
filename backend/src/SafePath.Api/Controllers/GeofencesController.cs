using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Geofencing;

namespace SafePath.Api.Controllers;

[ApiController]
[Authorize]
public sealed class GeofencesController : ControllerBase
{
    private readonly ICommandHandler<ListZonesQuery, IReadOnlyList<ZoneDto>> _list;
    private readonly ICommandHandler<CreateZoneCommand, ZoneMutationResult> _create;
    private readonly ICommandHandler<GetZoneQuery, ZoneDto?> _get;
    private readonly ICommandHandler<UpdateZoneCommand, ZoneMutationResult> _update;
    private readonly ICommandHandler<EnableZoneCommand, ZoneMutationResult> _enable;
    private readonly ICommandHandler<DisableZoneCommand, ZoneMutationResult> _disable;
    private readonly ICommandHandler<DeleteZoneCommand, ZoneMutationResult> _delete;
    private readonly ICommandHandler<GetMyZoneRegistrationsQuery, IReadOnlyList<ZoneDto>> _registrations;
    private readonly ICommandHandler<AcknowledgeCurrentZoneRegistrationCommand, bool> _acknowledge;
    private readonly ICommandHandler<GetGeofenceActivityQuery, IReadOnlyList<GeofenceActivityDto>> _activity;
    private readonly ICurrentUserService _currentUser;

    public GeofencesController(
        ICommandHandler<ListZonesQuery, IReadOnlyList<ZoneDto>> list,
        ICommandHandler<CreateZoneCommand, ZoneMutationResult> create,
        ICommandHandler<GetZoneQuery, ZoneDto?> get,
        ICommandHandler<UpdateZoneCommand, ZoneMutationResult> update,
        ICommandHandler<EnableZoneCommand, ZoneMutationResult> enable,
        ICommandHandler<DisableZoneCommand, ZoneMutationResult> disable,
        ICommandHandler<DeleteZoneCommand, ZoneMutationResult> delete,
        ICommandHandler<GetMyZoneRegistrationsQuery, IReadOnlyList<ZoneDto>> registrations,
        ICommandHandler<AcknowledgeCurrentZoneRegistrationCommand, bool> acknowledge,
        ICommandHandler<GetGeofenceActivityQuery, IReadOnlyList<GeofenceActivityDto>> activity,
        ICurrentUserService currentUser)
    {
        _list = list;
        _create = create;
        _get = get;
        _update = update;
        _enable = enable;
        _disable = disable;
        _delete = delete;
        _registrations = registrations;
        _acknowledge = acknowledge;
        _activity = activity;
        _currentUser = currentUser;
    }

    [HttpPost("families/{familyId:guid}/geofences")]
    public async Task<ActionResult<ZoneMutationResult>> Create(Guid familyId, CreateZoneRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var result = await _create.Handle(new CreateZoneCommand(userId, familyId, request.Category, request.CustomName,
                request.Latitude, request.Longitude, request.RadiusMeters, request.AssignedMemberUserId, request.Sensitivity,
                request.RecipientUserIds, request.NotifyAssignedMember), cancellationToken);
            return Created($"/families/{familyId}/geofences/{result.ZoneId}", result);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ZoneLimitReachedException exception) { return Conflict(new { error = exception.Message }); }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }

    [HttpGet("families/{familyId:guid}/geofences")]
    public async Task<ActionResult<IReadOnlyList<ZoneDto>>> List(Guid familyId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return Ok(await _list.Handle(new ListZonesQuery(userId, familyId), cancellationToken)); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpGet("families/{familyId:guid}/geofences/{zoneId:guid}")]
    public async Task<ActionResult<ZoneDto>> Get(Guid familyId, Guid zoneId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var zone = await _get.Handle(new GetZoneQuery(userId, familyId, zoneId), cancellationToken);
            return zone is null ? NotFound() : Ok(zone);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpPut("families/{familyId:guid}/geofences/{zoneId:guid}")]
    public async Task<ActionResult<ZoneMutationResult>> Update(Guid familyId, Guid zoneId, UpdateZoneRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            return Ok(await _update.Handle(new UpdateZoneCommand(userId, familyId, zoneId, request.Category, request.CustomName,
                request.Latitude, request.Longitude, request.RadiusMeters, request.AssignedMemberUserId, request.Sensitivity,
                request.RecipientUserIds, request.NotifyAssignedMember), cancellationToken));
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ZoneNotFoundException) { return NotFound(); }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }

    [HttpPost("families/{familyId:guid}/geofences/{zoneId:guid}/disable")]
    public async Task<ActionResult<ZoneMutationResult>> Disable(Guid familyId, Guid zoneId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return Ok(await _disable.Handle(new DisableZoneCommand(userId, familyId, zoneId), cancellationToken)); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ZoneNotFoundException) { return NotFound(); }
    }

    [HttpPost("families/{familyId:guid}/geofences/{zoneId:guid}/enable")]
    public async Task<ActionResult<ZoneMutationResult>> Enable(Guid familyId, Guid zoneId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return Ok(await _enable.Handle(new EnableZoneCommand(userId, familyId, zoneId), cancellationToken)); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ZoneLimitReachedException exception) { return Conflict(new { error = exception.Message }); }
        catch (ZoneNotFoundException) { return NotFound(); }
    }

    [HttpDelete("families/{familyId:guid}/geofences/{zoneId:guid}")]
    public async Task<IActionResult> Delete(Guid familyId, Guid zoneId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { await _delete.Handle(new DeleteZoneCommand(userId, familyId, zoneId), cancellationToken); return NoContent(); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ZoneNotFoundException) { return NotFound(); }
    }

    [HttpGet("geofences/registrations")]
    public async Task<ActionResult<IReadOnlyList<ZoneDto>>> GetRegistrations(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return Ok(await _registrations.Handle(new GetMyZoneRegistrationsQuery(userId), cancellationToken)); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpPost("geofences/{zoneId:guid}/registrations/{generation:int}/acknowledgements/current")]
    public async Task<IActionResult> Acknowledge(Guid zoneId, int generation, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return await _acknowledge.Handle(new AcknowledgeCurrentZoneRegistrationCommand(userId, zoneId, generation), cancellationToken) ? NoContent() : NotFound(); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpGet("families/{familyId:guid}/geofences/activity")]
    public async Task<ActionResult<IReadOnlyList<GeofenceActivityDto>>> GetActivity(
        Guid familyId,
        [FromQuery] Guid? memberUserId,
        [FromQuery] Guid? zoneId,
        [FromQuery] SafePath.Domain.Enums.GeofenceTransition? transition,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try { return Ok(await _activity.Handle(new GetGeofenceActivityQuery(userId, familyId, memberUserId, zoneId, transition, fromUtc, toUtc), cancellationToken)); }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }

    [HttpGet("families/{familyId:guid}/geofences/{zoneId:guid}/activity")]
    public Task<ActionResult<IReadOnlyList<GeofenceActivityDto>>> GetZoneActivity(
        Guid familyId,
        Guid zoneId,
        [FromQuery] Guid? memberUserId,
        [FromQuery] SafePath.Domain.Enums.GeofenceTransition? transition,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        CancellationToken cancellationToken) =>
        GetActivity(familyId, memberUserId, zoneId, transition, fromUtc, toUtc, cancellationToken);
}

public sealed record UpdateZoneRequest(
    SafePath.Domain.Enums.SafeZoneCategory Category,
    string? CustomName,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    Guid AssignedMemberUserId,
    SafePath.Domain.Enums.SafeZoneSensitivity Sensitivity,
    Guid[]? RecipientUserIds,
    bool NotifyAssignedMember);

public sealed record CreateZoneRequest(
    SafePath.Domain.Enums.SafeZoneCategory Category,
    string? CustomName,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    Guid AssignedMemberUserId,
    SafePath.Domain.Enums.SafeZoneSensitivity Sensitivity,
    Guid[]? RecipientUserIds,
    bool NotifyAssignedMember);
