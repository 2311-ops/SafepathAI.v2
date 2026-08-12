namespace SafePath.Application.Sos;

/// <summary>
/// Binds <c>Sos:LiveWindowMinutes</c> from configuration (default 15 minutes, same shape as
/// <c>FirebaseOptions</c>/<c>WhatsAppOptions</c>) so the live-location streaming window's duration
/// is configuration-driven rather than a hardcoded literal — a demo can shorten the window
/// without a rebuild. Read once by <see cref="TriggerSosCommandHandler"/> when stamping
/// <see cref="Domain.Entities.SosSession.LiveWindowEndsAtUtc"/> at session creation (D-21); the
/// window itself becomes a stamped, server-anchored <see cref="DateTime"/> on the session from
/// that point on, never re-derived from this option on every position report.
/// </summary>
public class SosLiveWindowOptions
{
    public int LiveWindowMinutes { get; set; } = 15;
}
