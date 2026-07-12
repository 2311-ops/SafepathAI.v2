using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Privacy;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

public record UpdateSharingPreferenceRequest(
    Guid? RecipientMemberId,
    SharedDataType DataType,
    bool IsEnabled,
    DateTime? ExpiresAtUtc);

[ApiController]
[Authorize]
public class PrivacyController : ControllerBase
{
    private readonly ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto> _getSharingMatrix;
    private readonly ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto> _updateSharingPreference;
    private readonly ICurrentUserService _currentUser;

    public PrivacyController(
        ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto> getSharingMatrix,
        ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto> updateSharingPreference,
        ICurrentUserService currentUser)
    {
        _getSharingMatrix = getSharingMatrix;
        _updateSharingPreference = updateSharingPreference;
        _currentUser = currentUser;
    }

    [HttpGet("families/{familyId:guid}/sharing-matrix")]
    public async Task<ActionResult<SharingMatrixDto>> GetSharingMatrix(Guid familyId, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var matrix = await _getSharingMatrix.Handle(new GetSharingMatrixQuery(userId, familyId), cancellationToken);
            return Ok(matrix);
        }
        catch (FamilyAuthorizationDeniedException)
        {
            return Forbid();
        }
    }

    [HttpPatch("families/{familyId:guid}/sharing-preferences")]
    public async Task<ActionResult<SharingPreferenceDto>> UpdateSharingPreference(
        Guid familyId,
        [FromBody] UpdateSharingPreferenceRequest request,
        CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _updateSharingPreference.Handle(
                new UpdateSharingPreferenceCommand(
                    userId,
                    familyId,
                    request.RecipientMemberId,
                    request.DataType,
                    request.IsEnabled,
                    request.ExpiresAtUtc),
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
}
