namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Generates the two secrets carried by a family invite (RESEARCH Pitfall 4): a short
/// human-readable display code (manual-entry fallback) and a longer opaque link token (the
/// actual security-bearing secret carried by the shareable link/QR payload). Both must come
/// from a CSPRNG — never <c>Guid.NewGuid()</c>.
/// </summary>
public interface IInviteCodeGenerator
{
    /// <summary>e.g. <c>SP-4K9X</c> — short, human-typeable, CSPRNG-backed.</summary>
    string GenerateDisplayCode();

    /// <summary>A longer opaque base64url token from a 32-byte CSPRNG payload.</summary>
    string GenerateLinkToken();
}
