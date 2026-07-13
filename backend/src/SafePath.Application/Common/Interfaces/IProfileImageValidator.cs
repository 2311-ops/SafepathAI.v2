namespace SafePath.Application.Common.Interfaces;

public interface IProfileImageValidator
{
    ValidatedImage Validate(byte[] rawBytes);
}

public sealed record ValidatedImage(byte[] JpegBytes, string ContentType);
