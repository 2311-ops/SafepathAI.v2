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

    public bool TransitionAlerted(Guid userId, Func<bool, (bool ShouldAlert, bool NextState)> transition)
    {
        var userLock = _userLocks.GetOrAdd(userId, _ => new object());
        lock (userLock)
        {
            var current = GetAlerted(userId);
            var (shouldAlert, nextState) = transition(current);
            SetAlerted(userId, nextState);
            return shouldAlert;
        }
    }

    private readonly ConcurrentDictionary<Guid, object> _userLocks = new();
}
