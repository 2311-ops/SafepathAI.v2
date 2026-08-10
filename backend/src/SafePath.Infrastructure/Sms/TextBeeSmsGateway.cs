using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// TextBee-backed <see cref="ISmsGateway"/> implementation, registered only when
/// <see cref="TextBeeOptions.IsConfigured"/> is true. Calls TextBee's send-sms REST API
/// (<c>POST {BaseUrl}/api/v1/gateway/devices/{DeviceId}/send-sms</c>) via a typed
/// <see cref="HttpClient"/>. A successful return here means only that TextBee's gateway device
/// accepted the message for sending, never that it was delivered — <c>SosAlertDispatcher</c>
/// records this as <see cref="SafePath.Domain.Enums.SosDeliveryStatus.Queued"/> exactly as it did
/// for the superseded Twilio implementation (D-10, unchanged). Because
/// <see cref="TextBeeWebhookSignatureValidator"/> never validates any inbound callback, a
/// TextBee-sent row stays at Queued — honestly "sent, unconfirmed" — forever, rather than ever
/// progressing to Delivered. This is the deliberate migration design, not a regression.
/// </summary>
public class TextBeeSmsGateway : ISmsGateway
{
    private readonly HttpClient _httpClient;
    private readonly TextBeeOptions _options;
    private readonly ILogger<TextBeeSmsGateway> _logger;

    public TextBeeSmsGateway(HttpClient httpClient, TextBeeOptions options, ILogger<TextBeeSmsGateway> logger)
    {
        _httpClient = httpClient;
        _options = options;
        _logger = logger;
    }

    public async Task<SmsSendResult> SendAsync(string toE164, string body, CancellationToken cancellationToken = default)
    {
        try
        {
            var requestUri = $"api/v1/gateway/devices/{_options.DeviceId}/send-sms";
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUri);
            request.Headers.TryAddWithoutValidation("x-api-key", _options.ApiKey);
            request.Content = JsonContent.Create(new TextBeeSendSmsRequest(new[] { toE164 }, body));

            using var response = await _httpClient.SendAsync(request, cancellationToken);
            response.EnsureSuccessStatusCode();

            var providerMessageId = await TryExtractProviderMessageIdAsync(response, cancellationToken);
            return new SmsSendResult(providerMessageId);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Do not surface the raw HTTP exception message up through the dispatcher's
            // FailureReason column — it can echo request details. Log the full exception here
            // (server-side only) and translate to a short, credential-free message.
            _logger.LogError(ex, "TextBeeSmsGateway failed to send an SMS.");
            throw new InvalidOperationException("Failed to send SMS via the configured provider.", ex);
        }
    }

    /// <summary>
    /// TextBee's exact success-response JSON shape is not independently verified (no research
    /// phase run for this small integration surface). Parses defensively for a <c>data</c> object
    /// containing a string id property named <c>_id</c>, <c>id</c>, <c>smsId</c>, or
    /// <c>messageId</c> (checked in that order); falls back to a synthetic id on any parse
    /// failure or unrecognised shape, matching <see cref="LoggingSmsGateway"/>'s synthetic-id
    /// convention. A send must never fail purely because the response shape did not match
    /// expectations.
    /// </summary>
    private static async Task<string> TryExtractProviderMessageIdAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        try
        {
            using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);

            if (document.RootElement.TryGetProperty("data", out var data) && data.ValueKind == JsonValueKind.Object)
            {
                foreach (var propertyName in new[] { "_id", "id", "smsId", "messageId" })
                {
                    if (data.TryGetProperty(propertyName, out var idElement) && idElement.ValueKind == JsonValueKind.String)
                    {
                        var value = idElement.GetString();
                        if (!string.IsNullOrWhiteSpace(value))
                        {
                            return value;
                        }
                    }
                }
            }
        }
        catch (JsonException)
        {
            // Fall through to the synthetic id below — an unexpected response shape must never
            // fail an otherwise-successful send.
        }

        return $"textbee-{Guid.NewGuid():N}";
    }

    private sealed record TextBeeSendSmsRequest(
        [property: JsonPropertyName("recipients")] IReadOnlyList<string> Recipients,
        [property: JsonPropertyName("message")] string Message);
}
