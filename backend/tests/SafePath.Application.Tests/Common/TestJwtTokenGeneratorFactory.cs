using Microsoft.Extensions.Configuration;
using SafePath.Infrastructure.Identity;

namespace SafePath.Application.Tests.Common;

/// <summary>
/// Builds a real <see cref="JwtTokenGenerator"/> backed by an in-memory test configuration
/// (never a mock) so tests exercise the actual HMAC-SHA256 signing + CSPRNG refresh-token path.
/// </summary>
public static class TestJwtTokenGeneratorFactory
{
    public static JwtTokenGenerator Create()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:Key"] = "test-only-signing-key-do-not-use-in-production-32bytes+",
                ["Jwt:Issuer"] = "SafePathTests",
                ["Jwt:Audience"] = "SafePathTests",
            })
            .Build();

        return new JwtTokenGenerator(config);
    }
}
