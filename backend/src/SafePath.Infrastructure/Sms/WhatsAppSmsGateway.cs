using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// WhatsApp Business Cloud API (Meta Graph API) backed <see cref="ISmsGateway"/> implementation,
/// registered only when <see cref="WhatsAppOptions.IsConfigured"/> is true. Calls Meta's
/// send-message endpoint (<c>POST {BaseUrl}/{ApiVersion}/{PhoneNumberId}/messages</c>) via a
/// typed <see cref="HttpClient"/>, sending a Utility-category template message (required — SOS
/// alerts are business-initiated and must work outside any 24h WhatsApp customer-service session
/// window; freeform text is not usable for this). A successful return here means only that Meta
/// accepted the message for sending, never that it was delivered — <c>SosAlertDispatcher</c>
/// records this as <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Queued"/> for every SMS
/// send (D-10, unchanged). Unlike the previously configured provider, Meta's Cloud API ships a
/// genuine HMAC-signed delivery-status webhook (see <see cref="WhatsAppWebhookSignatureValidator"/>
/// and <see cref="WhatsAppDeliveryStatusParser"/>), so a row sent through this gateway can now
/// genuinely progress to Delivered.
/// </summary>
public class WhatsAppSmsGateway : ISmsGateway
{
    private static readonly Regex WhitespaceRunPattern = new(@"[\s]+", RegexOptions.Compiled);

    private readonly HttpClient _httpClient;
    private readonly WhatsAppOptions _options;
    private readonly ILogger<WhatsAppSmsGateway> _logger;

    public WhatsAppSmsGateway(HttpClient httpClient, WhatsAppOptions options, ILogger<WhatsAppSmsGateway> logger)
    {
        _httpClient = httpClient;
        _options = options;
        _logger = logger;
    }

    public async Task<SmsSendResult> SendAsync(string toE164, string body, CancellationToken cancellationToken = default)
    {
        try
        {
            var requestUri = $"{_options.ApiVersion}/{_options.PhoneNumberId}/messages";
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);
            request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _options.AccessToken);

            var toDigitsOnly = toE164.TrimStart('+');
            var normalizedBody = NormalizeTemplateParameterText(body);

            var payload = new WhatsAppSendMessageRequest(
                MessagingProduct: "whatsapp",
                To: toDigitsOnly,
                Type: "template",
                Template: new WhatsAppTemplate(
                    Name: _options.TemplateName,
                    Language: new WhatsAppTemplateLanguage(_options.TemplateLanguage),
                    Components: new[]
                    {
                        new WhatsAppTemplateComponent(
                            Type: "body",
                            Parameters: new[] { new WhatsAppTemplateParameter("text", normalizedBody) }),
                    }));

            request.Content = JsonContent.Create(payload);

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogError(
                    "WhatsAppSmsGateway received a non-success response. Status: {StatusCode}. Body: {ErrorBody}",
                    (int)response.StatusCode,
                    errorBody);
                throw new InvalidOperationException("Failed to send SMS via the configured provider.");
            }

            var providerMessageId = await TryExtractProviderMessageIdAsync(response, cancellationToken);
            return new SmsSendResult(providerMessageId);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Do not surface the raw HTTP exception message up through the dispatcher's
            // FailureReason column — it can echo request/credential details. The non-success
            // branch above already threw the credential-free message and logged the raw error
            // server-side, so just propagate it unchanged here; any other exception (transport
            // failure, DNS, etc.) is logged and translated fresh.
            if (ex is InvalidOperationException)
            {
                throw;
            }

            _logger.LogError(ex, "WhatsAppSmsGateway failed to send an SMS.");
            throw new InvalidOperationException("Failed to send SMS via the configured provider.", ex);
        }
    }

    /// <summary>
    /// Meta rejects newlines, tabs, and runs of 4+ spaces inside template parameter text.
    /// Collapses every whitespace run to a single space and trims.
    /// </summary>
    private static string NormalizeTemplateParameterText(string body) =>
        WhitespaceRunPattern.Replace(body, " ").Trim();

    /// <summary>
    /// Extracts the provider message id defensively: parses the response stream, reads
    /// <c>messages[0].id</c> when present as a non-empty string, and falls back to a synthetic
    /// <c>whatsapp-{Guid:N}</c> id on any <see cref="JsonException"/> or unrecognized shape. A
    /// send must never fail purely because the response shape moved.
    /// </summary>
    private static async Task<string> TryExtractProviderMessageIdAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        try
        {
            using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

            if (document.RootElement.TryGetProperty("messages", out var messages) &&
                messages.ValueKind == JsonValueKind.Array &&
                messages.GetArrayLength() > 0)
            {
                var first = messages[0];
                if (first.TryGetProperty("id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
                {
                    var value = idElement.GetString();
                    if (!string.IsNullOrWhiteSpace(value))
                    {
                        return value;
                    }
                }
            }
        }
        catch (JsonException)
        {
            // Fall through to the synthetic id below — an unexpected response shape must never
            // fail an otherwise-successful send.
        }

        return $"whatsapp-{Guid.NewGuid():N}";
    }

    private sealed record WhatsAppSendMessageRequest(
        [property: JsonPropertyName("messaging_product")] string MessagingProduct,
        [property: JsonPropertyName("to")] string To,
        [property: JsonPropertyName("type")] string Type,
        [property: JsonPropertyName("template")] WhatsAppTemplate Template);

    private sealed record WhatsAppTemplate(
        [property: JsonPropertyName("name")] string Name,
        [property: JsonPropertyName("language")] WhatsAppTemplateLanguage Language,
        [property: JsonPropertyName("components")] IReadOnlyList<WhatsAppTemplateComponent> Components);

    private sealed record WhatsAppTemplateLanguage(
        [property: JsonPropertyName("code")] string Code);

    private sealed record WhatsAppTemplateComponent(
        [property: JsonPropertyName("type")] string Type,
        [property: JsonPropertyName("parameters")] IReadOnlyList<WhatsAppTemplateParameter> Parameters);

    private sealed record WhatsAppTemplateParameter(
        [property: JsonPropertyName("type")] string Type,
        [property: JsonPropertyName("text")] string Text);
}
