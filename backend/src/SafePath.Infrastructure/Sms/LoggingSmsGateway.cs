using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Zero-cost default <see cref="ISmsGateway"/> implementation, registered whenever TextBee
/// credentials are absent (D-07). Sends nothing; logs the destination (redacted to its last
/// four digits, threat T-03-21) and body at Information level and returns a synthetic message
/// id, so the whole SOS pipeline is exercisable with no account and no cost.
/// </summary>
public class LoggingSmsGateway : ISmsGateway
{
    private readonly ILogger<LoggingSmsGateway> _logger;

    public LoggingSmsGateway(ILogger<LoggingSmsGateway> logger)
    {
        _logger = logger;
    }

    public Task<SmsSendResult> SendAsync(string toE164, string body, CancellationToken cancellationToken = default)
    {
        var messageId = $"logging-{Guid.NewGuid():N}";
        _logger.LogInformation(
            "LoggingSmsGateway: would send SMS to {RedactedNumber} (synthetic id {MessageId}): {Body}",
            RedactAllButLastFour(toE164),
            messageId,
            body);

        return Task.FromResult(new SmsSendResult(messageId));
    }

    private static string RedactAllButLastFour(string phoneNumber)
    {
        if (string.IsNullOrEmpty(phoneNumber))
        {
            return "****";
        }

        if (phoneNumber.Length <= 4)
        {
            return new string('*', phoneNumber.Length);
        }

        var lastFour = phoneNumber[^4..];
        return new string('*', phoneNumber.Length - 4) + lastFour;
    }
}
