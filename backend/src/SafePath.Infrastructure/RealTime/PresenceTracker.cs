using System.Collections.Concurrent;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

public class PresenceTracker : IPresenceQuery
{
    private readonly ConcurrentDictionary<Guid, HashSet<string>> _connections = new();

    public bool AddConnection(Guid userId, string connectionId)
    {
        while (true)
        {
            var connections = _connections.GetOrAdd(userId, _ => []);

            lock (connections)
            {
                // The set we grabbed may have just been orphaned by a concurrent
                // RemoveConnection that removed it from the dictionary after we
                // read it but before we took the lock. Retry against the live entry.
                if (_connections.TryGetValue(userId, out var current) && !ReferenceEquals(current, connections))
                {
                    continue;
                }

                var wasOffline = connections.Count == 0;
                connections.Add(connectionId);
                return wasOffline;
            }
        }
    }

    public bool RemoveConnection(Guid userId, string connectionId)
    {
        while (true)
        {
            if (!_connections.TryGetValue(userId, out var connections))
            {
                return false;
            }

            lock (connections)
            {
                // Re-check we still own the current dictionary entry before mutating —
                // a concurrent AddConnection/RemoveConnection may have replaced or
                // removed it while we were waiting for the lock.
                if (!_connections.TryGetValue(userId, out var current) || !ReferenceEquals(current, connections))
                {
                    continue;
                }

                connections.Remove(connectionId);
                if (connections.Count > 0)
                {
                    return true;
                }

                _connections.TryRemove(new KeyValuePair<Guid, HashSet<string>>(userId, connections));
                return false;
            }
        }
    }

    public bool IsOnline(Guid userId) =>
        _connections.TryGetValue(userId, out var connections) && connections.Count > 0;
}
