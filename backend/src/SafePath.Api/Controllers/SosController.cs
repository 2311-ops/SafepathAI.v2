using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

namespace SafePath.Api.Controllers;

/// <summary>
/// Deliberately carries no rate-limiting attribute. D-17's offline retry storm must always
/// succeed, and a 429 on the one endpoint that must always work would contradict the Core
/// Value (threat T-03-05, accepted disposition — 03-RESEARCH.md Pitfall 4).
/// </summary>
[ApiController]
[Authorize]
public class SosController : ControllerBase
{
    private readonly ICommandHandler<TriggerSosCommand, TriggerSosResult> _triggerSos;
    private readonly ICommandHandler<GetSosSessionQuery, GetSosSessionResult> _getSosSession;
    private readonly ICommandHandler<AcknowledgeSosCommand, AcknowledgeSosResult> _acknowledgeSos;
    private readonly ICommandHandler<CancelSosCommand, CancelSosResult> _cancelSos;
    private readonly ICommandHandler<ReportSosLocationCommand, ReportSosLocationResult> _reportSosLocation;
    private readonly ICurrentUserService _currentUser;

    public SosController(
        ICommandHandler<TriggerSosCommand, TriggerSosResult> triggerSos,
        ICommandHandler<GetSosSessionQuery, GetSosSessionResult> getSosSession,
        ICommandHandler<AcknowledgeSosCommand, AcknowledgeSosResult> acknowledgeSos,
        ICommandHandler<CancelSosCommand, CancelSosResult> cancelSos,
        ICommandHandler<ReportSosLocationCommand, ReportSosLocationResult> reportSosLocation,
        ICurrentUserService currentUser)
    {
        _triggerSos = triggerSos;
        _getSosSession = getSosSession;
        _acknowledgeSos = acknowledgeSos;
        _cancelSos = cancelSos;
        _reportSosLocation = reportSosLocation;
        _currentUser = currentUser;
    }

    [HttpPost("sos/trigger")]
    public async Task<ActionResult<TriggerSosResult>> Trigger(
        [FromBody] TriggerSosRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _triggerSos.Handle(
                new TriggerSosCommand(
                    request.SosSessionId,
                    userId,
                    request.FamilyId,
                    request.Latitude,
                    request.Longitude,
                    request.AccuracyMeters,
                    request.TriggeredAtUtc),
                cancellationToken);

            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpGet("sos/{sosSessionId:guid}")]
    public async Task<ActionResult<SosSessionDto>> Get(Guid sosSessionId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _getSosSession.Handle(new GetSosSessionQuery(userId, sosSessionId), cancellationToken);
            if (result.Session is null)
            {
                return NotFound();
            }

            return Ok(result.Session);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>No rate-limit attribute here either — a guardian acknowledging must never be
    /// throttled.</summary>
    [HttpPost("sos/{sosSessionId:guid}/acknowledge")]
    public async Task<ActionResult<AcknowledgeSosResult>> Acknowledge(Guid sosSessionId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _acknowledgeSos.Handle(new AcknowledgeSosCommand(sosSessionId, userId), cancellationToken);
            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>No rate-limit attribute here either — a user correcting a false alarm is
    /// time-sensitive and must never be throttled.</summary>
    [HttpPost("sos/{sosSessionId:guid}/cancel")]
    public async Task<ActionResult<CancelSosResult>> Cancel(Guid sosSessionId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _cancelSos.Handle(new CancelSosCommand(sosSessionId, userId), cancellationToken);
            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>No rate-limit attribute here either — the live-location stream must keep working
    /// under the same D-17 offline-retry-storm guarantee as the trigger endpoint itself. Always
    /// echoes the server's own window-end time (even on a WindowClosed refusal) so the client can
    /// self-terminate its foreground service instead of retrying forever.</summary>
    [HttpPost("sos/{sosSessionId:guid}/location")]
    public async Task<ActionResult<ReportSosLocationResult>> ReportLocation(
        Guid sosSessionId,
        [FromBody] ReportSosLocationRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _reportSosLocation.Handle(
                new ReportSosLocationCommand(
                    sosSessionId,
                    userId,
                    request.Latitude,
                    request.Longitude,
                    request.AccuracyMeters,
                    request.RecordedAtUtc),
                cancellationToken);

            if (result.Outcome == ReportSosLocationOutcome.SessionNotFound)
            {
                return NotFound();
            }

            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}

/// <summary>Request body for POST /sos/trigger — CallerUserId is never bound from here; it comes
/// exclusively from <see cref="ICurrentUserService"/> (threat T-03-01).</summary>
public record TriggerSosRequest(
    Guid SosSessionId,
    Guid FamilyId,
    double? Latitude,
    double? Longitude,
    double? AccuracyMeters,
    DateTime TriggeredAtUtc);

/// <summary>Request body for POST /sos/{sosSessionId}/location — CallerUserId is never bound
/// from here either; it comes exclusively from <see cref="ICurrentUserService"/>.</summary>
public record ReportSosLocationRequest(
    double Latitude,
    double Longitude,
    double? AccuracyMeters,
    DateTime RecordedAtUtc);
