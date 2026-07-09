using System.Security.Cryptography;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Identity;

/// <summary>
/// CSPRNG-backed invite secrets (RESEARCH Pitfall 4). The display code uses an alphabet with
/// visually ambiguous characters (0/O, 1/I) removed, since it is meant for manual/QR-fallback
/// entry; the link token is a much longer opaque secret that is the actual security boundary.
/// </summary>
public class InviteCodeGenerator : IInviteCodeGenerator
{
    private const string DisplayAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private const int DisplayCodeLength = 6;
    private const int LinkTokenByteLength = 32;

    public string GenerateDisplayCode()
    {
        var bytes = RandomNumberGenerator.GetBytes(DisplayCodeLength);
        var chars = new char[DisplayCodeLength];
        for (var i = 0; i < DisplayCodeLength; i++)
        {
            chars[i] = DisplayAlphabet[bytes[i] % DisplayAlphabet.Length];
        }

        return $"SP-{new string(chars)}";
    }

    public string GenerateLinkToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(LinkTokenByteLength);
        return Convert.ToBase64String(bytes)
            .Replace('+', '-')
            .Replace('/', '_')
            .TrimEnd('=');
    }
}
