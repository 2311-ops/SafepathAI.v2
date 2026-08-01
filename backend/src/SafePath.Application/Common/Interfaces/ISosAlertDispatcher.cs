namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// SOS-only multi-channel fan-out dispatcher. Takes only a session id (not caller-supplied
/// recipient state) so it stays re-runnable from a retry path.
/// </summary>
public interface ISosAlertDispatcher
{
    Task DispatchAsync(Guid sosSessionId, CancellationToken cancellationToken = default);
}
