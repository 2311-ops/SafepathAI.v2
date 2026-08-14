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
    private readonly ICurrentUserService _currentUser;

    public NotificationsController(
        ICommandHandler<GetRoutineNotificationsQuery, IReadOnlyList<RoutineNotificationDto>> getFeed,
        ICommandHandler<MarkRoutineNotificationReadCommand, bool> markRead,
        ICurrentUserService currentUser)
    {
        _getFeed = getFeed;
        _markRead = markRead;
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
}
