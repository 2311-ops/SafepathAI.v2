using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Push;

/// <summary>
/// Zero-cost routine sender used when Firebase is not configured. It has a distinct type and
/// registration from <see cref="LoggingPushSender"/> so normal geofence work can never select
/// the SOS sender by accident.
/// </summary>
public sealed class LoggingRoutinePushSender : IRoutinePushSender
{
    private readonly ILogger<LoggingRoutinePushSender> _logger;

    public LoggingRoutinePushSender(ILogger<LoggingRoutinePushSender> logger) => _logger = logger;

    public Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "LoggingRoutinePushSender: would send routine push {Title} to {TokenCount} device token(s)",
            message.Title,
            tokens.Count);

        return Task.FromResult(new PushSendResult(tokens.Count, Array.Empty<string>()));
    }
}
