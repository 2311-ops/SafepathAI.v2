using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Geofencing;

namespace SafePath.Api.Controllers;

[ApiController]
[Authorize]
public sealed class NotificationsController : ControllerBase
{
    private readonly ICommandHandler<GetRoutineNotificationsQuery, IReadOnlyList<RoutineNotificationDto>> _getFeed;
    private readonly ICommandHandler<MarkRoutineNotificationReadCommand, bool> _markRead;
    private readonly ICommandHandler<GetQuietHoursQuery, QuietHoursDto> _getQuietHours;
    private readonly ICommandHandler<UpdateQuietHoursCommand, QuietHoursDto> _updateQuietHours;
    private readonly ICurrentUserService _currentUser;

    public NotificationsController(
        ICommandHandler<GetRoutineNotificationsQuery, IReadOnlyList<RoutineNotificationDto>> getFeed,
        ICommandHandler<MarkRoutineNotificationReadCommand, bool> markRead,
        ICommandHandler<GetQuietHoursQuery, QuietHoursDto> getQuietHours,
        ICommandHandler<UpdateQuietHoursCommand, QuietHoursDto> updateQuietHours,
        ICurrentUserService currentUser)
    {
        _getFeed = getFeed;
        _markRead = markRead;
        _getQuietHours = getQuietHours;
        _updateQuietHours = updateQuietHours;
        _currentUser = currentUser;
    }

    [HttpGet("notifications")]
    public async Task<ActionResult<IReadOnlyList<RoutineNotificationDto>>> Get(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        return Ok(await _getFeed.Handle(new GetRoutineNotificationsQuery(userId), cancellationToken));
    }

    [HttpPost("notifications/{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        return await _markRead.Handle(new MarkRoutineNotificationReadCommand(userId, id), cancellationToken)
            ? NoContent()
            : NotFound();
    }

    [HttpGet("notifications/quiet-hours")]
    public async Task<ActionResult<QuietHoursDto>> GetQuietHours(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        return Ok(await _getQuietHours.Handle(new GetQuietHoursQuery(userId), cancellationToken));
    }

    [HttpPut("notifications/quiet-hours")]
    public async Task<ActionResult<QuietHoursDto>> UpdateQuietHours(
        UpdateQuietHoursRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();
        try
        {
            return Ok(await _updateQuietHours.Handle(
                new UpdateQuietHoursCommand(userId, request.IsEnabled, request.LocalStart, request.LocalEnd, request.TimeZoneId),
                cancellationToken));
        }
        catch (ArgumentException exception) { return BadRequest(new { error = exception.Message }); }
    }
}

public sealed record UpdateQuietHoursRequest(bool IsEnabled, TimeOnly LocalStart, TimeOnly LocalEnd, string TimeZoneId);
