namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Provider-agnostic push seam — keeps Firebase (or any provider) entirely out of the
/// Application layer. Implemented in Infrastructure by <c>LoggingPushSender</c> (zero-cost
/// default) and <c>FirebasePushSender</c> (registered only when Firebase credentials are
/// configured), mirroring <see cref="ISmsGateway"/>'s exact seam shape.
/// </summary>
public interface IPushSender
{
    /// <summary>
    /// Sends <paramref name="message"/> to every token in <paramref name="tokens"/>. A successful
    /// return means only that the provider (FCM) accepted the message for delivery to each
    /// token — never write <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Delivered"/> from
    /// this alone (D-10). <see cref="PushSendResult.InvalidTokens"/> lets the caller prune
    /// registrations FCM has rejected as unregistered, so a stale token never silently
    /// accumulates as a false-negative delivery target.
    /// </summary>
    Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default);
}

/// <summary>The notification's user-visible title/body plus the data payload the tap handler reads.</summary>
public record PushMessage(string Title, string Body, IReadOnlyDictionary<string, string> Data);

/// <summary>How many of the requested tokens the provider accepted, and which ones it rejected as unregistered.</summary>
public record PushSendResult(int SuccessCount, IReadOnlyList<string> InvalidTokens);
