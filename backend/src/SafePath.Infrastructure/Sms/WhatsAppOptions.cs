namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Binds <c>WhatsApp:AccessToken</c>, <c>WhatsApp:PhoneNumberId</c>, <c>WhatsApp:WabaId</c>,
/// <c>WhatsApp:AppSecret</c>, <c>WhatsApp:WebhookVerifyToken</c>, <c>WhatsApp:TemplateName</c>,
/// <c>WhatsApp:TemplateLanguage</c>, <c>WhatsApp:BaseUrl</c>, and <c>WhatsApp:ApiVersion</c> from
/// configuration. Never committed — every value here loads from the local gitignored
/// <c>backend/.env</c> through the existing <c>DotNetEnv</c> double-underscore mapping in
/// <c>Program.cs</c> (threat T-WGL-01). <see cref="IsConfigured"/> gates which
/// <c>ISmsGateway</c> implementation is registered: <c>LoggingSmsGateway</c> whenever either
/// <see cref="AccessToken"/> or <see cref="PhoneNumberId"/> is missing, so a fresh clone
/// builds/tests/demos the whole SOS pipeline with no WhatsApp Business account and no cost
/// (D-07, same zero-cost-default shape as <c>FirebaseOptions</c>). <see cref="AppSecret"/> and
/// <see cref="WebhookVerifyToken"/> are deliberately NOT part of this gate — they gate the
/// inbound delivery-status callback independently, so an operator who has configured sending but
/// not yet the webhook can still send.
/// </summary>
public class WhatsAppOptions
{
    public string? AccessToken { get; set; }
    public string? PhoneNumberId { get; set; }
    public string? WabaId { get; set; }
    public string? AppSecret { get; set; }
    public string? WebhookVerifyToken { get; set; }
    public string TemplateName { get; set; } = "sos_alert";
    public string TemplateLanguage { get; set; } = "en";
    public string BaseUrl { get; set; } = "https://graph.facebook.com";
    public string ApiVersion { get; set; } = "v22.0";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(AccessToken) && !string.IsNullOrWhiteSpace(PhoneNumberId);
}
