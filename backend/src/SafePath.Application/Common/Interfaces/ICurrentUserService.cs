using SafePath.Domain.Enums;

namespace SafePath.Application.Common.Interfaces;

/// <summary>Reads the authenticated caller's identity from the current HTTP request's claims.</summary>
public interface ICurrentUserService
{
    Guid? UserId { get; }
    Role? Role { get; }
}
