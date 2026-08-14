using Microsoft.Extensions.Logging.Abstractions;
using SafePath.Application.Common.Interfaces;
using SafePath.Infrastructure.Push;
using Xunit;

namespace SafePath.Application.Tests.Geofencing;

/// <summary>
/// Guards the routine-notification delivery boundary.  Routine pushes intentionally use a
/// separate sender seam so their normal-priority provider settings cannot leak into SOS.
/// </summary>
public sealed class RoutineNotificationDispatcherTests
{
    [Fact]
    public async Task LoggingRoutineSender_UsesTheRoutineOnlySeam()
    {
        var sender = new LoggingRoutinePushSender(
            NullLogger<LoggingRoutinePushSender>.Instance);
        var message = new PushMessage(
            "Sam entered Home",
            "Sam entered Home",
            new Dictionary<string, string>
            {
                ["type"] = "geofence",
                ["activityId"] = Guid.NewGuid().ToString(),
                ["zoneId"] = Guid.NewGuid().ToString(),
            });

        var result = await sender.SendAsync(new[] { "routine-token" }, message);

        Assert.False(typeof(IPushSender).IsAssignableFrom(typeof(IRoutinePushSender)));
        Assert.Equal(1, result.SuccessCount);
        Assert.Empty(result.InvalidTokens);
    }
}
