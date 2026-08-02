using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Push;

/// <summary>
/// Zero-cost default <see cref="IPushSender"/> implementation, registered whenever Firebase
/// credentials are absent (D-07). Sends nothing; logs the title, body and token count at
/// Information level — never the token values themselves (threat T-03-03) — and returns a
/// success count equal to the token count, so the whole SOS pipeline is exercisable with no
/// Firebase project and no cost.
/// </summary>
public class LoggingPushSender : IPushSender
{
    private readonly ILogger<LoggingPushSender> _logger;

    public LoggingPushSender(ILogger<LoggingPushSender> logger)
    {
        _logger = logger;
    }

    public Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "LoggingPushSender: would send push {Title}: {Body} to {TokenCount} device token(s)",
            message.Title,
            message.Body,
            tokens.Count);

        return Task.FromResult(new PushSendResult(tokens.Count, Array.Empty<string>()));
    }
}
