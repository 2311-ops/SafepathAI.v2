namespace SafePath.Application.Location;

public static class LowBatteryEvaluator
{
    private const int AlertThreshold = 20;
    private const int ClearThreshold = 25;

    public static bool ShouldAlert(bool alreadyAlerted, int? batteryPercent, out bool newAlertedState)
    {
        if (batteryPercent is null)
        {
            newAlertedState = alreadyAlerted;
            return false;
        }

        if (alreadyAlerted)
        {
            newAlertedState = batteryPercent <= ClearThreshold;
            return false;
        }

        if (batteryPercent <= AlertThreshold)
        {
            newAlertedState = true;
            return true;
        }

        newAlertedState = false;
        return false;
    }
}
