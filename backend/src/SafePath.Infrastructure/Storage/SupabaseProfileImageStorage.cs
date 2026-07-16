using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Storage;

public class SupabaseProfileImageStorage : IProfileImageStorage
{
    private const string AvatarFileName = "avatar.jpg";
    private readonly HttpClient _httpClient;
    private readonly string _bucketName;

    public SupabaseProfileImageStorage(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _bucketName = configuration["Supabase:AvatarBucket"] ?? "avatar";
    }

    public string GetAvatarObjectPath(Guid userId)
    {
        return $"avatars/{userId:D}/{AvatarFileName}";
    }

    public async Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default)
    {
        var objectPath = GetAvatarObjectPath(userId);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"object/{Uri.EscapeDataString(_bucketName)}/{objectPath}")
        {
            Content = new ByteArrayContent(jpegBytes),
        };
        request.Content.Headers.ContentType = new("image/jpeg");
        request.Headers.Add("x-upsert", "true");

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    public async Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var objectPath = GetAvatarObjectPath(userId);
        using var request = new HttpRequestMessage(HttpMethod.Delete, $"object/{Uri.EscapeDataString(_bucketName)}")
        {
            Content = JsonContent.Create(new DeleteObjectsRequest([objectPath])),
        };

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
    }

    public async Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default)
    {
        using var response = await _httpClient.PostAsJsonAsync(
            $"object/sign/{Uri.EscapeDataString(_bucketName)}/{objectPath}",
            new CreateSignedUrlRequest((int)Math.Ceiling(ttl.TotalSeconds)),
            cancellationToken);

        response.EnsureSuccessStatusCode();

        var result = await response.Content.ReadFromJsonAsync<CreateSignedUrlResponse>(cancellationToken);
        if (string.IsNullOrWhiteSpace(result?.SignedUrl))
        {
            throw new InvalidOperationException("Supabase Storage did not return a signedURL value.");
        }

        return new Uri(_httpClient.BaseAddress!, result.SignedUrl.TrimStart('/')).ToString();
    }

    private sealed record DeleteObjectsRequest([property: JsonPropertyName("prefixes")] string[] Prefixes);

    private sealed record CreateSignedUrlRequest([property: JsonPropertyName("expiresIn")] int ExpiresIn);

    private sealed record CreateSignedUrlResponse([property: JsonPropertyName("signedURL")] string SignedUrl);
}
