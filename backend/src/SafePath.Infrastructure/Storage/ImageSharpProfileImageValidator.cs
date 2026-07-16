using SafePath.Application.Common.Interfaces;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using SixLabors.ImageSharp.Formats.Jpeg;

namespace SafePath.Infrastructure.Storage;

public class ImageSharpProfileImageValidator : IProfileImageValidator
{
    public const int MaxUploadBytes = 5 * 1024 * 1024;
    public const int MaxDimension = 4000;
    private const string JpegContentType = "image/jpeg";

    public ValidatedImage Validate(byte[] rawBytes)
    {
        if (rawBytes.Length == 0)
        {
            throw new ArgumentException("Profile image is required.", nameof(rawBytes));
        }

        if (rawBytes.Length > MaxUploadBytes)
        {
            throw new ArgumentException("Profile image must be 5 MB or smaller.", nameof(rawBytes));
        }

        if (!HasAllowedImageSignature(rawBytes))
        {
            throw new ArgumentException("Profile image must be a JPEG, PNG, or WebP image.", nameof(rawBytes));
        }

        using var identifyStream = new MemoryStream(rawBytes, writable: false);
        var imageInfo = IdentifyAllowedImage(identifyStream);

        if (imageInfo.Width > MaxDimension || imageInfo.Height > MaxDimension)
        {
            throw new ArgumentException("Profile image dimensions must be 4000x4000 px or smaller.", nameof(rawBytes));
        }

        using var loadStream = new MemoryStream(rawBytes, writable: false);
        using var image = LoadImage(loadStream);
        using var output = new MemoryStream();
        image.Save(output, new JpegEncoder { Quality = 85 });

        return new ValidatedImage(output.ToArray(), JpegContentType);
    }

    private static ImageInfo IdentifyAllowedImage(Stream stream)
    {
        try
        {
            var imageInfo = Image.Identify(stream)
                ?? throw new ArgumentException("Profile image could not be identified.");
            var format = imageInfo.Metadata.DecodedImageFormat;

            if (!IsAllowedFormat(format))
            {
                throw new ArgumentException("Profile image must be a JPEG, PNG, or WebP image.");
            }

            return imageInfo;
        }
        catch (ArgumentException)
        {
            throw;
        }
        catch (Exception exception) when (exception is UnknownImageFormatException or InvalidImageContentException)
        {
            throw new ArgumentException("Profile image must be a valid JPEG, PNG, or WebP image.", exception);
        }
    }

    private static Image LoadImage(Stream stream)
    {
        try
        {
            return Image.Load(stream);
        }
        catch (Exception exception) when (exception is UnknownImageFormatException or InvalidImageContentException)
        {
            throw new ArgumentException("Profile image must be a valid JPEG, PNG, or WebP image.", exception);
        }
    }

    private static bool HasAllowedImageSignature(byte[] bytes)
    {
        return HasJpegSignature(bytes) || HasPngSignature(bytes) || HasWebpSignature(bytes);
    }

    private static bool HasJpegSignature(byte[] bytes)
    {
        return bytes.Length >= 3 &&
            bytes[0] == 0xFF &&
            bytes[1] == 0xD8 &&
            bytes[2] == 0xFF;
    }

    private static bool HasPngSignature(byte[] bytes)
    {
        return bytes.Length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0D &&
            bytes[5] == 0x0A &&
            bytes[6] == 0x1A &&
            bytes[7] == 0x0A;
    }

    private static bool HasWebpSignature(byte[] bytes)
    {
        return bytes.Length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50;
    }

    private static bool IsAllowedFormat(IImageFormat? format)
    {
        return format?.Name is "JPEG" or "PNG" or "WEBP";
    }
}
