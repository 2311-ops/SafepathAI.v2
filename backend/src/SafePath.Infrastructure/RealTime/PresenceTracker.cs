using System.Collections.Concurrent;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

public class PresenceTracker : IPresenceQuery
{
    private readonly ConcurrentDictionary<Guid, PresenceState> _presence = new();

    public bool AddConnection(Guid userId, string connectionId, DateTime changedAtUtc)
    {
        while (true)
        {
            var state = _presence.GetOrAdd(userId, _ => new PresenceState());

            lock (state.Connections)
            {
                if (_presence.TryGetValue(userId, out var current) && !ReferenceEquals(current, state))
                {
                    continue;
                }

                var wasOffline = state.Connections.Count == 0;
                state.Connections.Add(connectionId);
                state.LastSeenAtUtc = changedAtUtc;
                return wasOffline;
            }
        }
    }

    public bool RemoveConnection(Guid userId, string connectionId, DateTime changedAtUtc)
    {
        while (true)
        {
            if (!_presence.TryGetValue(userId, out var state))
            {
                return false;
            }

            lock (state.Connections)
            {
                if (!_presence.TryGetValue(userId, out var current) || !ReferenceEquals(current, state))
                {
                    continue;
                }

                state.Connections.Remove(connectionId);
                state.LastSeenAtUtc = changedAtUtc;
                return state.Connections.Count > 0;
            }
        }
    }

    public bool IsOnline(Guid userId) =>
        _presence.TryGetValue(userId, out var state) && state.Connections.Count > 0;

    public DateTime? LastSeenAtUtc(Guid userId) =>
        _presence.TryGetValue(userId, out var state) ? state.LastSeenAtUtc : null;

    private sealed class PresenceState
    {
        public HashSet<string> Connections { get; } = [];

        public DateTime? LastSeenAtUtc { get; set; }
    }
}
