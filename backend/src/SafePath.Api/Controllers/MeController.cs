using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Profile;
using SafePath.Domain.Enums;

namespace SafePath.Api.Controllers;

public record UpdateMyRoleRequest(Role Role);

public record UpdateDisplayNameRequest(string DisplayName);

[ApiController]
[Route("me")]
[Authorize]
public class MeController : ControllerBase
{
    private readonly ICurrentUserService _currentUser;
    private readonly ICommandHandler<GetMeQuery, GetMeResult> _getMe;
    private readonly ICommandHandler<UpdateMyRoleCommand, GetMeResult> _updateMyRole;
    private readonly ICommandHandler<UpdateDisplayNameCommand, GetMeResult> _updateDisplayName;
    private readonly ICommandHandler<UploadProfileImageCommand, GetMeResult> _uploadProfileImage;
    private readonly ICommandHandler<DeleteProfileImageCommand, GetMeResult> _deleteProfileImage;

    public MeController(
        ICurrentUserService currentUser,
        ICommandHandler<GetMeQuery, GetMeResult> getMe,
        ICommandHandler<UpdateMyRoleCommand, GetMeResult> updateMyRole,
        ICommandHandler<UpdateDisplayNameCommand, GetMeResult> updateDisplayName,
        ICommandHandler<UploadProfileImageCommand, GetMeResult> uploadProfileImage,
        ICommandHandler<DeleteProfileImageCommand, GetMeResult> deleteProfileImage)
    {
        _currentUser = currentUser;
        _getMe = getMe;
        _updateMyRole = updateMyRole;
        _updateDisplayName = updateDisplayName;
        _uploadProfileImage = uploadProfileImage;
        _deleteProfileImage = deleteProfileImage;
    }

    [HttpGet]
    public async Task<ActionResult> Get(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _getMe.Handle(new GetMeQuery(userId), cancellationToken);

        return Ok(ToResponse(result));
    }

    [HttpPatch("role")]
    public async Task<ActionResult> UpdateRole([FromBody] UpdateMyRoleRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _updateMyRole.Handle(
            new UpdateMyRoleCommand(
                userId,
                request.Role,
                User.FindFirstValue("email"),
                User.FindFirstValue("name") ?? User.FindFirstValue("full_name")),
            cancellationToken);

        return Ok(ToResponse(result));
    }

    [HttpPatch("display-name")]
    public async Task<ActionResult> UpdateDisplayName([FromBody] UpdateDisplayNameRequest request, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            var result = await _updateDisplayName.Handle(new UpdateDisplayNameCommand(userId, request.DisplayName), cancellationToken);
            return Ok(ToResponse(result));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpPost("profile-image")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(6_000_000)]
    public async Task<ActionResult> UploadProfileImage([FromForm] IFormFile file, CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        try
        {
            await using var stream = file.OpenReadStream();
            using var buffer = new MemoryStream();
            await stream.CopyToAsync(buffer, cancellationToken);

            var result = await _uploadProfileImage.Handle(new UploadProfileImageCommand(userId, buffer.ToArray()), cancellationToken);
            return Ok(ToResponse(result));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpDelete("profile-image")]
    public async Task<ActionResult> DeleteProfileImage(CancellationToken cancellationToken)
    {
        if (_currentUser.UserId is not { } userId)
        {
            return Unauthorized();
        }

        var result = await _deleteProfileImage.Handle(new DeleteProfileImageCommand(userId), cancellationToken);
        return Ok(ToResponse(result));
    }

    private object ToResponse(GetMeResult result)
    {
        return new
        {
            userId = result.UserId,
            role = result.Role?.ToString(),
            email = result.Email ?? User.FindFirstValue("email"),
            fullName = result.FullName,
            displayName = result.DisplayName,
            profileImageUrl = result.ProfileImageUrl,
            profileUpdatedAt = result.ProfileUpdatedAt,
            subject = User.FindFirstValue("sub"),
        };
    }
}
