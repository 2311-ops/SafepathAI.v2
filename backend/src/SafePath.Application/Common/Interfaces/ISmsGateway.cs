namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Provider-agnostic SMS seam — keeps TextBee (or any provider) entirely out of the Application
/// layer. Implemented in Infrastructure by <c>LoggingSmsGateway</c> (zero-cost default) and
/// <c>TextBeeSmsGateway</c> (registered only when TextBee credentials are configured).
/// </summary>
public interface ISmsGateway
{
    /// <summary>
    /// Sends an SMS to <paramref name="toE164"/>. A successful return means only that the
    /// provider accepted the message for delivery — never write
    /// <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Delivered"/> from this alone (D-10).
    /// </summary>
    Task<SmsSendResult> SendAsync(string toE164, string body, CancellationToken cancellationToken = default);
}

/// <summary>The provider's message id, used later to match an inbound delivery-status webhook.</summary>
public record SmsSendResult(string ProviderMessageId);
