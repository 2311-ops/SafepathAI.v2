using PhoneNumbers;

namespace SafePath.Application.Sos;

/// <summary>
/// Normalises a user-entered phone number into strict E.164 form using
/// <c>libphonenumber-csharp</c>'s <see cref="PhoneNumberUtil"/> — never a hand-rolled regex.
/// International phone number formats (country codes, trunk prefixes, extensions) are a
/// classic "deceptively simple" problem; a naive pattern would silently reject or mis-store
/// valid numbers, breaking SMS delivery for exactly the emergency contacts a user most needs
/// reached (03-RESEARCH.md "Don't Hand-Roll").
/// </summary>
public static class PhoneNumberNormalizer
{
    /// <summary>Fallback region used only when no region hint is supplied by the caller.</summary>
    public const string DefaultRegionFallback = "US";

    /// <summary>
    /// Parses <paramref name="input"/> (optionally aided by <paramref name="defaultRegion"/> for
    /// national-format numbers with no leading country code) and returns a strict E.164 string
    /// (leading '+', digits only after it). Throws <see cref="ArgumentException"/> when the
    /// number cannot be parsed or is not a valid number for the resolved region.
    /// </summary>
    public static string ToE164(string input, string? defaultRegion = null)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            throw new ArgumentException("Phone number is required.", nameof(input));
        }

        var region = string.IsNullOrWhiteSpace(defaultRegion) ? DefaultRegionFallback : defaultRegion;
        var util = PhoneNumberUtil.GetInstance();

        PhoneNumber parsed;
        try
        {
            parsed = util.Parse(input, region);
        }
        catch (NumberParseException ex)
        {
            throw new ArgumentException($"'{input}' could not be parsed as a phone number: {ex.Message}", nameof(input));
        }

        if (!util.IsValidNumber(parsed))
        {
            throw new ArgumentException($"'{input}' is not a valid phone number.", nameof(input));
        }

        return util.Format(parsed, PhoneNumberFormat.E164);
    }
}
