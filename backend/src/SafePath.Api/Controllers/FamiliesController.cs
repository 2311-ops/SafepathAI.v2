using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

public record CreateFamilyRequest(string Name);

public record CreateFamilyResponse(Guid FamilyId);

public record UpdateMemberPermissionsRequest(PermissionLevel Permissions);

[ApiController]
[Authorize]
public class FamiliesController : ControllerBase
{
    private readonly ICommandHandler<CreateFamilyCommand, Guid> _createFamily;
    private readonly ICommandHandler<ListFamilyMembersQuery, IReadOnlyList<FamilyMemberDto>> _listMembers;
    private readonly ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult> _updatePermissions;
    private readonly ICommandHandler<RemoveMemberCommand, RemoveMemberResult> _removeMember;
    private readonly ICurrentUserService _currentUser;

    public FamiliesController(
        ICommandHandler<CreateFamilyCommand, Guid> createFamily,
        ICommandHandler<ListFamilyMembersQuery, IReadOnlyList<FamilyMemberDto>> listMembers,
        ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult> updatePermissions,
        ICommandHandler<RemoveMemberCommand, RemoveMemberResult> removeMember,
        ICurrentUserService currentUser)
    {
        _createFamily = createFamily;
        _listMembers = listMembers;
        _updatePermissions = updatePermissions;
        _removeMember = removeMember;
        _currentUser = currentUser;
    }

    /// <summary>Creates a family circle; the caller becomes its first Guardian (FAM-01).</summary>
    [HttpPost("families")]
    public async Task<ActionResult<CreateFamilyResponse>> Create([FromBody] CreateFamilyRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var familyId = await _createFamily.Handle(new CreateFamilyCommand(userId, request.Name), cancellationToken);
            return Ok(new CreateFamilyResponse(familyId));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    /// <summary>Lists the active members of a family; membership-gated (IDOR prevention).</summary>
    [HttpGet("families/{familyId:guid}/members")]
    public async Task<ActionResult<IReadOnlyList<FamilyMemberDto>>> GetMembers(Guid familyId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var members = await _listMembers.Handle(new ListFamilyMembersQuery(userId, familyId), cancellationToken);
            return Ok(members);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>Guardian-only: update a member's visibility permission level (FAM-04).</summary>
    [HttpPatch("families/{familyId:guid}/members/{memberId:guid}/permissions")]
    public async Task<ActionResult<UpdateMemberPermissionsResult>> UpdatePermissions(
        Guid familyId, Guid memberId, [FromBody] UpdateMemberPermissionsRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _updatePermissions.Handle(
                new UpdateMemberPermissionsCommand(userId, familyId, memberId, request.Permissions), cancellationToken);
            return Ok(result);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    /// <summary>Guardian-only: soft-remove a member from the family (FAM-05).</summary>
    [HttpDelete("families/{familyId:guid}/members/{memberId:guid}")]
    public async Task<ActionResult> RemoveMember(Guid familyId, Guid memberId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            await _removeMember.Handle(new RemoveMemberCommand(userId, familyId, memberId), cancellationToken);
            return NoContent();
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }
}
