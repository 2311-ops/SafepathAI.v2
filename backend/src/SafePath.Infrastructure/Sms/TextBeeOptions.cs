namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Binds <c>TextBee:ApiKey</c>, <c>TextBee:DeviceId</c>, and <c>TextBee:BaseUrl</c> from
/// configuration. Never committed — read from environment / local secrets only (threat
/// T-VCF-01). <see cref="IsConfigured"/> gates which <c>ISmsGateway</c> implementation is
/// registered: <c>LoggingSmsGateway</c> whenever either <see cref="ApiKey"/> or
/// <see cref="DeviceId"/> is missing, so a fresh clone builds/tests/demos with no TextBee gateway
/// device and no cost (same D-07 zero-cost-default shape as <c>FirebaseOptions</c>).
/// <see cref="BaseUrl"/> is never part of the gate — it always has a usable default of TextBee's
/// public API.
/// </summary>
public class TextBeeOptions
{
    public string? ApiKey { get; set; }
    public string? DeviceId { get; set; }
    public string BaseUrl { get; set; } = "https://api.textbee.dev";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ApiKey) && !string.IsNullOrWhiteSpace(DeviceId);
}
