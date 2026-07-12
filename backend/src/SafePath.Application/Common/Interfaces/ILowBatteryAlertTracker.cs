namespace SafePath.Application.Common.Interfaces;

public interface ILowBatteryAlertTracker
{
    bool GetAlerted(Guid userId);

    void SetAlerted(Guid userId, bool alreadyAlerted);

    /// <summary>
    /// Atomically reads the current alerted state, applies <paramref name="transition"/> to
    /// decide whether an alert should fire and the next state, and stores the next state —
    /// so concurrent callers for the same user can't both observe the pre-transition state
    /// and both trigger an alert. Returns the transition's ShouldAlert result.
    /// </summary>
    bool TransitionAlerted(Guid userId, Func<bool, (bool ShouldAlert, bool NextState)> transition);
}
