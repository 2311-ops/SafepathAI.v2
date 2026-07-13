using System.Text;
using SafePath.Application.Common.Interfaces;
using SafePath.Infrastructure.Storage;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.PixelFormats;

namespace SafePath.Application.Tests.Profile;

public class ImageValidationTests
{
    private readonly IProfileImageValidator _validator = new ImageSharpProfileImageValidator();

    [Fact]
    public void Validate_AcceptsPngAndReturnsJpeg()
    {
        var result = _validator.Validate(CreateImageBytes("png"));

        Assert.Equal("image/jpeg", result.ContentType);
        Assert.NotEmpty(result.JpegBytes);
        AssertImageFormat(result.JpegBytes, "JPEG");
    }

    [Theory]
    [InlineData("jpeg")]
    [InlineData("webp")]
    public void Validate_AcceptsJpegAndWebpUnderCaps(string format)
    {
        var result = _validator.Validate(CreateImageBytes(format));

        Assert.Equal("image/jpeg", result.ContentType);
        Assert.NotEmpty(result.JpegBytes);
        AssertImageFormat(result.JpegBytes, "JPEG");
    }

    [Fact]
    public void Validate_RejectsNonImageMagicBytes()
    {
        var payload = Encoding.UTF8.GetBytes("not an image");

        Assert.Throws<ArgumentException>(() => _validator.Validate(payload));
    }

    [Fact]
    public void Validate_RejectsDeclaredDimensionsAboveCap()
    {
        using var image = new Image<Rgba32>(4001, 1);
        using var stream = new MemoryStream();
        image.Save(stream, new PngEncoder());

        Assert.Throws<ArgumentException>(() => _validator.Validate(stream.ToArray()));
    }

    [Fact]
    public void Validate_RejectsPayloadLargerThanFiveMb()
    {
        var payload = new byte[5 * 1024 * 1024 + 1];
        payload[0] = 0xFF;
        payload[1] = 0xD8;
        payload[2] = 0xFF;

        Assert.Throws<ArgumentException>(() => _validator.Validate(payload));
    }

    [Fact]
    public void Validate_ReencodeDiscardsTrailingPayloadBytes()
    {
        var imageBytes = CreateImageBytes("jpeg");
        var trailingPayload = Encoding.ASCII.GetBytes("ZIP_OR_SCRIPT_PAYLOAD");
        var polyglot = imageBytes.Concat(trailingPayload).ToArray();

        var result = _validator.Validate(polyglot);

        Assert.Equal("image/jpeg", result.ContentType);
        Assert.False(ContainsSequence(result.JpegBytes, trailingPayload));
        AssertImageFormat(result.JpegBytes, "JPEG");
    }

    private static byte[] CreateImageBytes(string format)
    {
        using var image = new Image<Rgba32>(2, 2);
        image[0, 0] = new Rgba32(0, 120, 90);
        image[1, 0] = new Rgba32(10, 160, 120);
        image[0, 1] = new Rgba32(20, 180, 130);
        image[1, 1] = new Rgba32(30, 200, 140);

        using var stream = new MemoryStream();
        switch (format)
        {
            case "png":
                image.Save(stream, new PngEncoder());
                break;
            case "jpeg":
                image.Save(stream, new JpegEncoder { Quality = 90 });
                break;
            case "webp":
                image.Save(stream, new WebpEncoder { Quality = 90 });
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(format), format, null);
        }

        return stream.ToArray();
    }

    private static void AssertImageFormat(byte[] bytes, string expectedFormat)
    {
        using var stream = new MemoryStream(bytes);
        var metadata = Image.Identify(stream);

        Assert.NotNull(metadata);
        Assert.Equal(expectedFormat, metadata.Metadata.DecodedImageFormat?.Name);
    }

    private static bool ContainsSequence(byte[] haystack, byte[] needle)
    {
        if (needle.Length == 0)
        {
            return true;
        }

        for (var index = 0; index <= haystack.Length - needle.Length; index++)
        {
            if (haystack.AsSpan(index, needle.Length).SequenceEqual(needle))
            {
                return true;
            }
        }

        return false;
    }
}
