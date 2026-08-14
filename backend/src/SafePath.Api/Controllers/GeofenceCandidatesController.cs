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
    private readonly ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?> _getRegistration;
    private readonly ICommandHandler<AcknowledgeCurrentZoneRegistrationCommand, bool> _acknowledgeRegistration;
    private readonly ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult> _submitCandidate;
    private readonly ICurrentUserService _currentUser;

    public GeofenceCandidatesController(
        ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?> getRegistration,
        ICommandHandler<AcknowledgeCurrentZoneRegistrationCommand, bool> acknowledgeRegistration,
        ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult> submitCandidate,
        ICurrentUserService currentUser)
    {
        _getRegistration = getRegistration;
        _acknowledgeRegistration = acknowledgeRegistration;
        _submitCandidate = submitCandidate;
        _currentUser = currentUser;
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
            var acknowledged = await _acknowledgeRegistration.Handle(new AcknowledgeCurrentZoneRegistrationCommand(userId, zoneId, generation), cancellationToken);
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

public sealed record SubmitGeofenceCandidateRequest(
    Guid EventId,
    Guid ZoneId,
    int RegistrationGeneration,
    GeofenceTransition Transition,
    DateTime OccurredAtUtc,
    double Latitude,
    double Longitude,
    double AccuracyMeters);
