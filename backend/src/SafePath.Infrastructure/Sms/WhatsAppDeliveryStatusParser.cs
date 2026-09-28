using System.Text.Json;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Sms;

/// <summary>
/// Parses the WhatsApp Business Cloud API's delivery-status webhook payload
/// (<c>entry[].changes[].value.statuses[]</c>) into provider-agnostic
/// <see cref="SmsDeliveryStatusUpdate"/> records. Walks the payload defensively — every step
/// guarded by <c>TryGetProperty</c> and a <c>ValueKind</c> check — so a malformed or unrelated
/// payload never throws, only ever returns an empty list (an unparseable callback must not 500
/// back at Meta and trigger its retry/disable behavior). Maps <c>delivered</c> and <c>read</c>
/// both to <see cref="SmsDeliveryOutcome.Delivered"/> (read strictly implies delivered, and a
/// recipient may have read receipts disabled, so treating read as Delivered is correct and never
/// downgrades); <c>failed</c> to <see cref="SmsDeliveryOutcome.Failed"/> with a reason drawn from
/// the entry's <c>errors</c> array; <c>sent</c> and anything else produce no update at all — the
/// message has only been accepted so far, not received.
/// </summary>
public class WhatsAppDeliveryStatusParser : ISmsDeliveryStatusParser
{
    private const int MaxFailureReasonLength = 500;

    public IReadOnlyList<SmsDeliveryStatusUpdate> Parse(string rawBody)
    {
        var updates = new List<SmsDeliveryStatusUpdate>();

        try
        {
            using var document = JsonDocument.Parse(rawBody);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                return updates;
            }

            if (!document.RootElement.TryGetProperty("entry", out var entries) || entries.ValueKind != JsonValueKind.Array)
            {
                return updates;
            }

            foreach (var entry in entries.EnumerateArray())
            {
                if (!entry.TryGetProperty("changes", out var changes) || changes.ValueKind != JsonValueKind.Array)
                {
                    continue;
                }

                foreach (var change in changes.EnumerateArray())
                {
                    if (!change.TryGetProperty("value", out var value) || value.ValueKind != JsonValueKind.Object)
                    {
                        continue;
                    }

                    if (!value.TryGetProperty("statuses", out var statuses) || statuses.ValueKind != JsonValueKind.Array)
                    {
                        continue;
                    }

                    foreach (var status in statuses.EnumerateArray())
                    {
                        var update = ParseStatus(status);
                        if (update is not null)
                        {
                            updates.Add(update);
                        }
                    }
                }
            }
        }
        catch (JsonException)
        {
            return new List<SmsDeliveryStatusUpdate>();
        }

        return updates;
    }

    private static SmsDeliveryStatusUpdate? ParseStatus(JsonElement status)
    {
        if (status.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        if (!status.TryGetProperty("id", out var idElement) || idElement.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var providerMessageId = idElement.GetString();
        if (string.IsNullOrWhiteSpace(providerMessageId))
        {
            return null;
        }

        if (!status.TryGetProperty("status", out var statusElement) || statusElement.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var statusValue = statusElement.GetString()?.Trim().ToLowerInvariant();

        return statusValue switch
        {
            "delivered" or "read" => new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Delivered, null),
            "failed" => new SmsDeliveryStatusUpdate(providerMessageId, SmsDeliveryOutcome.Failed, ExtractFailureReason(status)),
            _ => null,
        };
    }

    private static string? ExtractFailureReason(JsonElement status)
    {
        if (!status.TryGetProperty("errors", out var errors) || errors.ValueKind != JsonValueKind.Array)
        {
            return null;
        }

        foreach (var error in errors.EnumerateArray())
        {
            if (error.ValueKind != JsonValueKind.Object)
            {
                continue;
            }

            var reason = TryGetStringProperty(error, "code") ?? TryGetStringProperty(error, "title");
            if (!string.IsNullOrWhiteSpace(reason))
            {
                return reason.Length > MaxFailureReasonLength ? reason[..MaxFailureReasonLength] : reason;
            }
        }

        return null;
    }

    private static string? TryGetStringProperty(JsonElement element, string propertyName)
    {
        if (!element.TryGetProperty(propertyName, out var value))
        {
            return null;
        }

        return value.ValueKind switch
        {
            JsonValueKind.String => value.GetString(),
            JsonValueKind.Number => value.GetRawText(),
            _ => null,
        };
    }
}
