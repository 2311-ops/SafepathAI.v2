using System.Collections.Concurrent;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

public class LowBatteryAlertTracker : ILowBatteryAlertTracker
{
    private readonly ConcurrentDictionary<Guid, bool> _alertedUsers = new();

    public bool GetAlerted(Guid userId) =>
        _alertedUsers.TryGetValue(userId, out var alreadyAlerted) && alreadyAlerted;

    public void SetAlerted(Guid userId, bool alreadyAlerted)
    {
        if (alreadyAlerted)
        {
            _alertedUsers[userId] = true;
            return;
        }

        _alertedUsers.TryRemove(userId, out _);
    }
}
