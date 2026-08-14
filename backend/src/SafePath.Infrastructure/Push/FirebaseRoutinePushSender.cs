using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Push;

/// <summary>
/// Normal-priority FCM/APNs delivery for durable geofence routine notifications. The named
/// Firebase app is intentionally separate from the SOS sender instance, keeping routine
/// transport configuration structurally unable to alter emergency priority or its channel.
/// </summary>
public sealed class FirebaseRoutinePushSender : IRoutinePushSender
{
    private const string RoutineFirebaseAppName = "SafePathRoutine";
    private static readonly object InitLock = new();
    private static FirebaseApp? _app;

    private readonly FirebaseOptions _options;
    private readonly ILogger<FirebaseRoutinePushSender> _logger;

    public FirebaseRoutinePushSender(
        FirebaseOptions options,
        ILogger<FirebaseRoutinePushSender> logger)
    {
        _options = options;
        _logger = logger;
    }

    public async Task<PushSendResult> SendAsync(
        IReadOnlyList<string> tokens,
        PushMessage message,
        CancellationToken cancellationToken = default)
    {
        if (tokens.Count == 0)
        {
            return new PushSendResult(0, Array.Empty<string>());
        }

        var messaging = FirebaseMessaging.GetMessaging(GetOrCreateApp());

#pragma warning disable CS0618 // MulticastMessage.Tokens remains the Firebase Admin SDK multicast token API.
        var multicast = new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification
            {
                Title = message.Title,
                Body = message.Body,
            },
            Data = message.Data,
            Android = new AndroidConfig
            {
                Priority = Priority.Normal,
                Notification = new AndroidNotification
                {
                    ChannelId = "safepath_routine",
                },
            },
            Apns = new ApnsConfig
            {
                Headers = new Dictionary<string, string>
                {
                    ["apns-priority"] = "5",
                    ["apns-push-type"] = "alert",
                },
                Aps = new Aps
                {
                    ContentAvailable = true,
                },
            },
        };
#pragma warning restore CS0618

        var response = await messaging.SendEachForMulticastAsync(multicast, cancellationToken);
        var invalidTokens = new List<string>();
        for (var index = 0; index < response.Responses.Count; index++)
        {
            var sendResponse = response.Responses[index];
            if (!sendResponse.IsSuccess
                && sendResponse.Exception is FirebaseMessagingException fcmException
                && fcmException.MessagingErrorCode == MessagingErrorCode.Unregistered)
            {
                invalidTokens.Add(tokens[index]);
            }
        }

        return new PushSendResult(response.SuccessCount, invalidTokens);
    }

    private FirebaseApp GetOrCreateApp()
    {
        if (_app is not null)
        {
            return _app;
        }

        lock (InitLock)
        {
            if (_app is not null)
            {
                return _app;
            }

            _logger.LogInformation("Initialising routine FirebaseApp for project {ProjectId}.", _options.ProjectId);
#pragma warning disable CS0618 // Explicit local service-account credentials match the SOS sender's proven configuration.
            _app = FirebaseApp.Create(new AppOptions
            {
                Credential = GoogleCredential.FromFile(_options.CredentialsPath),
                ProjectId = _options.ProjectId,
            }, RoutineFirebaseAppName);
#pragma warning restore CS0618
            return _app;
        }
    }
}
