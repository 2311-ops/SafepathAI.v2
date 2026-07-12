using System.Collections.Concurrent;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

public class PresenceTracker : IPresenceQuery
{
    private readonly ConcurrentDictionary<Guid, HashSet<string>> _connections = new();

    public bool AddConnection(Guid userId, string connectionId)
    {
        var connections = _connections.GetOrAdd(userId, _ => []);

        lock (connections)
        {
            var wasOffline = connections.Count == 0;
            connections.Add(connectionId);
            return wasOffline;
        }
    }

    public bool RemoveConnection(Guid userId, string connectionId)
    {
        if (!_connections.TryGetValue(userId, out var connections))
        {
            return false;
        }

        lock (connections)
        {
            connections.Remove(connectionId);
            if (connections.Count > 0)
            {
                return true;
            }

            _connections.TryRemove(userId, out _);
            return false;
        }
    }

    public bool IsOnline(Guid userId) =>
        _connections.TryGetValue(userId, out var connections) && connections.Count > 0;
}
