using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
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
    private readonly ICommandHandler<ExportMyDataQuery, MyDataExportDto> _exportMyData;
    private readonly ICommandHandler<DeleteMyDataCommand, DeleteMyDataResult> _deleteMyData;
    private readonly ICurrentUserService _currentUser;
    private readonly JsonOptions _jsonOptions;

    public PrivacyController(
        ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto> getSharingMatrix,
        ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto> updateSharingPreference,
        ICommandHandler<ExportMyDataQuery, MyDataExportDto> exportMyData,
        ICommandHandler<DeleteMyDataCommand, DeleteMyDataResult> deleteMyData,
        ICurrentUserService currentUser,
        IOptions<JsonOptions> jsonOptions)
    {
        _getSharingMatrix = getSharingMatrix;
        _updateSharingPreference = updateSharingPreference;
        _exportMyData = exportMyData;
        _deleteMyData = deleteMyData;
        _currentUser = currentUser;
        _jsonOptions = jsonOptions.Value;
    }

    [HttpGet("privacy/export")]
    public async Task<IActionResult> ExportMyData(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var export = await _exportMyData.Handle(new ExportMyDataQuery(userId), cancellationToken);
        var bytes = JsonSerializer.SerializeToUtf8Bytes(export, _jsonOptions.JsonSerializerOptions);
        return File(bytes, "application/json", "safepath-export.json");
    }

    [HttpDelete("privacy/my-data")]
    public async Task<ActionResult<DeleteMyDataResult>> DeleteMyData(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _deleteMyData.Handle(new DeleteMyDataCommand(userId), cancellationToken);
        return Ok(result);
    }

    [HttpGet("privacy/policy")]
    public ActionResult<PrivacyPolicyDto> GetPolicy() =>
        Ok(new PrivacyPolicyDto(
            "SafePath Privacy Commitment",
            "SafePath does not sell, rent, or resell family location, health, or safety data. Family safety data is used only to provide the safety features a user turns on.",
            "SafePath collects location pings when location sharing is enabled so approved family members can see live location, history, travel stats, and safety context.",
            "Location records are retained to power family history and stats until the user deletes them. Privacy sharing preferences are retained so SafePath can enforce the user's current choices.",
            "Users can export their own location and sharing data as JSON and can permanently delete their own location records from the Privacy Center."));

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
