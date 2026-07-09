using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using SafePath.Application.Common.Interfaces;
using DomainRole = SafePath.Domain.Enums.Role;

namespace SafePath.Infrastructure.Identity;

/// <summary>
/// Reads the authenticated caller from the current HTTP request.
/// Supabase always includes <c>sub</c> for the user id. App-specific roles can
/// be surfaced later with a custom access-token hook.
/// </summary>
public class CurrentUserService : ICurrentUserService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid? UserId
    {
        get
        {
            var principal = _httpContextAccessor.HttpContext?.User;
            var sub = principal?.FindFirst("sub")?.Value
                ?? principal?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            return Guid.TryParse(sub, out var id) ? id : null;
        }
    }

    public DomainRole? Role
    {
        get
        {
            var role = _httpContextAccessor.HttpContext?.User?.FindFirst("app_role")?.Value
                ?? _httpContextAccessor.HttpContext?.User?.FindFirst("user_role")?.Value
                ?? _httpContextAccessor.HttpContext?.User?.FindFirst(ClaimTypes.Role)?.Value;
            return Enum.TryParse<DomainRole>(role, out var parsed) ? parsed : null;
        }
    }
}
