namespace SafePath.Infrastructure.Push;

/// <summary>
/// Binds <c>Firebase:ProjectId</c> and <c>Firebase:CredentialsPath</c> from configuration. Never
/// committed — <c>GOOGLE_APPLICATION_CREDENTIALS</c> points at a service-account JSON file kept
/// outside the repository (threat T-03-08). <see cref="IsConfigured"/> gates which
/// <c>IPushSender</c> implementation is registered: <c>LoggingPushSender</c> whenever either
/// value is missing, so a fresh clone builds/tests/demos with no Firebase project and no spend
/// (D-07, same shape as <c>TwilioOptions</c>).
/// </summary>
public class FirebaseOptions
{
    public string? ProjectId { get; set; }
    public string? CredentialsPath { get; set; }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(ProjectId) && !string.IsNullOrWhiteSpace(CredentialsPath);
}
