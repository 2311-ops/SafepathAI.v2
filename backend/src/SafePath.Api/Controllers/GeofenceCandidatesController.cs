using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Geofencing;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

[ApiController]
[Authorize]
public sealed class GeofenceCandidatesController : ControllerBase
{
    private readonly ICommandHandler<CreateSafeZoneCommand, CreateSafeZoneResult> _createZone;
    private readonly ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?> _getRegistration;
    private readonly ICommandHandler<AcknowledgeSafeZoneRegistrationCommand, bool> _acknowledgeRegistration;
    private readonly ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult> _submitCandidate;
    private readonly ICurrentUserService _currentUser;

    public GeofenceCandidatesController(
        ICommandHandler<CreateSafeZoneCommand, CreateSafeZoneResult> createZone,
        ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?> getRegistration,
        ICommandHandler<AcknowledgeSafeZoneRegistrationCommand, bool> acknowledgeRegistration,
        ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult> submitCandidate,
        ICurrentUserService currentUser)
    {
        _createZone = createZone;
        _getRegistration = getRegistration;
        _acknowledgeRegistration = acknowledgeRegistration;
        _submitCandidate = submitCandidate;
        _currentUser = currentUser;
    }

    [HttpPost("families/{familyId:guid}/geofences")]
    public async Task<ActionResult<CreateSafeZoneResult>> CreateZone(Guid familyId, CreateSafeZoneRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var result = await _createZone.Handle(new CreateSafeZoneCommand(userId, familyId, request.Category, request.CustomName,
                request.Latitude, request.Longitude, request.RadiusMeters, request.AssignedMemberUserId, request.Sensitivity,
                request.RecipientUserIds ?? [], request.NotifyAssignedMember), cancellationToken);
            return Created($"/geofences/{result.ZoneId}", result);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }

    [HttpGet("geofences/registration")]
    public async Task<ActionResult<SafeZoneRegistrationDto>> GetRegistration(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var registration = await _getRegistration.Handle(new GetMySafeZoneRegistrationQuery(userId), cancellationToken);
            return registration is null ? NotFound() : Ok(registration);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpPost("geofences/{zoneId:guid}/registrations/{generation:int}/acknowledgements")]
    public async Task<IActionResult> AcknowledgeRegistration(Guid zoneId, int generation, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var acknowledged = await _acknowledgeRegistration.Handle(new AcknowledgeSafeZoneRegistrationCommand(userId, zoneId, generation), cancellationToken);
            return acknowledged ? NoContent() : NotFound();
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
    }

    [HttpPost("geofences/candidates")]
    public async Task<ActionResult<SubmitGeofenceCandidateResult>> SubmitCandidate(SubmitGeofenceCandidateRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            var result = await _submitCandidate.Handle(new SubmitGeofenceCandidateCommand(userId, request.EventId, request.ZoneId,
                request.RegistrationGeneration, request.Transition, request.OccurredAtUtc, request.Latitude, request.Longitude,
                request.AccuracyMeters), cancellationToken);
            return result.Outcome == GeofenceCandidateOutcome.Accepted ? Accepted(result) : Ok(result);
        }
        catch (FamilyAuthorizationDeniedException) { return Forbid(); }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }
}

public sealed record CreateSafeZoneRequest(
    SafeZoneCategory Category,
    string? CustomName,
    double Latitude,
    double Longitude,
    double RadiusMeters,
    Guid AssignedMemberUserId,
    SafeZoneSensitivity Sensitivity,
    Guid[]? RecipientUserIds,
    bool NotifyAssignedMember);

public sealed record SubmitGeofenceCandidateRequest(
    Guid EventId,
    Guid ZoneId,
    int RegistrationGeneration,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    double Latitude,
    double Longitude,
    double AccuracyMeters);
