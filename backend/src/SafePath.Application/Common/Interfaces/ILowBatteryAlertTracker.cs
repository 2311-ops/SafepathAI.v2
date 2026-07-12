namespace SafePath.Application.Common.Interfaces;

public interface ILowBatteryAlertTracker
{
    bool GetAlerted(Guid userId);

    void SetAlerted(Guid userId, bool alreadyAlerted);
}
