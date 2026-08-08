namespace SafePath.Domain.Enums;

/// <summary>
/// Distinguishes a visible SOS trigger from a covert one. Phase 3 only ever writes
/// <see cref="Visible"/> — <see cref="Duress"/> exists purely as a forward-compatibility
/// placeholder for Phase 6 (Silent/Duress) and has no behaviour attached in this phase (D-29).
/// </summary>
public enum SosKind
{
    Visible,
    Duress,
}
