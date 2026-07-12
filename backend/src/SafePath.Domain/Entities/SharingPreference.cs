using SafePath.Domain.Enums;

namespace SafePath.Domain.Entities;

/// <summary>
/// Owner-controlled sharing toggle for one data type. A null recipient means the owner's
/// default for every active member of the family; explicit recipient rows override it.
/// </summary>
public class SharingPreference
{
    public Guid Id { get; set; }
    public Guid FamilyId { get; set; }
    public Guid OwnerUserId { get; set; }
    public Guid? RecipientMemberId { get; set; }
    public SharedDataType DataType { get; set; }
    public bool IsEnabled { get; set; }
    public DateTime? ExpiresAtUtc { get; set; }
}
