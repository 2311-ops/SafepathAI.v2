namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Routine-notification-only push seam. This deliberately does not inherit from
/// <see cref="IPushSender"/>: SOS owns the emergency sender and its high-priority transport
/// settings, while geofence activity is allowed to be deferred and retried independently.
/// </summary>
public interface IRoutinePushSender
{
    /// <summary>
    /// Sends an ordinary routine payload to the recipient's registered devices. A successful
    /// return only confirms provider acceptance; callers retain the durable job until they make
    /// their own delivery-state decision.
    /// </summary>
    Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default);
}
