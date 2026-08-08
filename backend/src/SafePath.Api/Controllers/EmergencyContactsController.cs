using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;

namespace SafePath.Api.Controllers;

/// <summary>
/// Owner-scoped emergency-contact CRUD. Every route derives the owner exclusively from
/// <see cref="ICurrentUserService"/> — no request body ever carries an owner id (threat T-03-20).
/// </summary>
[ApiController]
[Authorize]
public class EmergencyContactsController : ControllerBase
{
    private readonly ICommandHandler<AddEmergencyContactCommand, EmergencyContactDto> _add;
    private readonly ICommandHandler<UpdateEmergencyContactCommand, EmergencyContactDto> _update;
    private readonly ICommandHandler<DeleteEmergencyContactCommand, EmergencyContactDto> _delete;
    private readonly ICommandHandler<ListEmergencyContactsQuery, IReadOnlyList<EmergencyContactDto>> _list;
    private readonly ICurrentUserService _currentUser;

    public EmergencyContactsController(
        ICommandHandler<AddEmergencyContactCommand, EmergencyContactDto> add,
        ICommandHandler<UpdateEmergencyContactCommand, EmergencyContactDto> update,
        ICommandHandler<DeleteEmergencyContactCommand, EmergencyContactDto> delete,
        ICommandHandler<ListEmergencyContactsQuery, IReadOnlyList<EmergencyContactDto>> list,
        ICurrentUserService currentUser)
    {
        _add = add;
        _update = update;
        _delete = delete;
        _list = list;
        _currentUser = currentUser;
    }

    [HttpGet("me/emergency-contacts")]
    public async Task<ActionResult<IReadOnlyList<EmergencyContactDto>>> List(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _list.Handle(new ListEmergencyContactsQuery(userId), cancellationToken);
        return Ok(result);
    }

    [HttpPost("me/emergency-contacts")]
    public async Task<ActionResult<EmergencyContactDto>> Add(
        [FromBody] EmergencyContactRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _add.Handle(
                new AddEmergencyContactCommand(userId, request.DisplayName, request.PhoneNumber, request.Region),
                cancellationToken);
            return Ok(result);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPut("me/emergency-contacts/{contactId:guid}")]
    public async Task<ActionResult<EmergencyContactDto>> Update(
        Guid contactId,
        [FromBody] EmergencyContactRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _update.Handle(
                new UpdateEmergencyContactCommand(userId, contactId, request.DisplayName, request.PhoneNumber, request.Region),
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

    [HttpDelete("me/emergency-contacts/{contactId:guid}")]
    public async Task<ActionResult<EmergencyContactDto>> Delete(Guid contactId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _delete.Handle(new DeleteEmergencyContactCommand(userId, contactId), cancellationToken);
            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }
}

/// <summary>Request body shared by Add/Update — CallerUserId is never bound from here.</summary>
public record EmergencyContactRequest(string DisplayName, string PhoneNumber, string? Region);
