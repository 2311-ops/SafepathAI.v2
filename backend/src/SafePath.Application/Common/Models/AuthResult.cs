namespace SafePath.Application.Common.Models;

/// <summary>
/// Uniform result shape returned by every auth command handler. <see cref="Invalid"/> is used
/// both for "wrong password" and "unknown email" so the API never leaks which field was wrong
/// (enumeration-safe, AUTH-02).
/// </summary>
public class AuthResult
{
    public bool Succeeded { get; init; }
    public string? AccessToken { get; init; }
    public string? RefreshToken { get; init; }
    public string? Error { get; init; }

    public static AuthResult Success(string accessToken, string refreshToken) => new()
    {
        Succeeded = true,
        AccessToken = accessToken,
        RefreshToken = refreshToken,
    };

    public static AuthResult Invalid(string error = "Invalid credentials") => new()
    {
        Succeeded = false,
        Error = error,
    };
}
