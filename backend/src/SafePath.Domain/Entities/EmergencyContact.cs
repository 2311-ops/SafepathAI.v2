namespace SafePath.Domain.Entities;

/// <summary>
/// A non-app emergency contact (e.g. a relative without the app installed) reachable only via
/// SMS. Phone numbers are stored E.164-normalised (plan 03-05 uses libphonenumber-csharp for
/// normalisation, never a hand-rolled regex).
/// </summary>
public class EmergencyContact
{
    public Guid Id { get; set; }
    public Guid OwnerUserId { get; set; }
    public string DisplayName { get; set; } = default!;
    public string PhoneNumberE164 { get; set; } = default!;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}
