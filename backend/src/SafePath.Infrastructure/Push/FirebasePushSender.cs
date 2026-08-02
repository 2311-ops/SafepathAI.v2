using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.Push;

/// <summary>
/// <see cref="IPushSender"/> over the Firebase Admin SDK. Initialises exactly one
/// <see cref="FirebaseApp"/> from the service-account credentials named by
/// <see cref="FirebaseOptions"/> (never committed — threat T-03-08) and sends one multicast per
/// call. The payload carries a data message (so the app's tap handler can route to the exact SOS
/// session even when the app is fully terminated) plus a notification block for the OS to render.
/// Android priority and APNs headers are both set to the platform's "deliver now" tier — an
/// emergency push that the OS defers to a batching window defeats the whole channel.
/// </summary>
public class FirebasePushSender : IPushSender
{
    private static readonly object InitLock = new();
    private static FirebaseApp? _app;

    private readonly FirebaseOptions _options;
    private readonly ILogger<FirebasePushSender> _logger;

    public FirebasePushSender(FirebaseOptions options, ILogger<FirebasePushSender> logger)
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

        var app = GetOrCreateApp();
        var messaging = FirebaseMessaging.GetMessaging(app);

#pragma warning disable CS0618 // MulticastMessage.Tokens is FCM registration tokens (UserDeviceToken.Token) -- Fids is the unrelated Firebase Installations feature, not a drop-in replacement here.
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
                Priority = Priority.High,
                Notification = new AndroidNotification
                {
                    ChannelId = "safepath_sos",
                },
            },
            Apns = new ApnsConfig
            {
                Headers = new Dictionary<string, string>
                {
                    ["apns-priority"] = "10",
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
        for (var i = 0; i < response.Responses.Count; i++)
        {
            var sendResponse = response.Responses[i];
            if (!sendResponse.IsSuccess
                && sendResponse.Exception is FirebaseMessagingException fcmException
                && fcmException.MessagingErrorCode == MessagingErrorCode.Unregistered)
            {
                invalidTokens.Add(tokens[i]);
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

            _logger.LogInformation("Initialising FirebaseApp for project {ProjectId}.", _options.ProjectId);
#pragma warning disable CS0618 // FromFile is the documented way to load a locally-stored service-account key path (GOOGLE_APPLICATION_CREDENTIALS); the suggested CredentialFactory path targets ADC discovery, not an explicit file path.
            _app = FirebaseApp.Create(new AppOptions
            {
                Credential = GoogleCredential.FromFile(_options.CredentialsPath),
                ProjectId = _options.ProjectId,
            });
#pragma warning restore CS0618

            return _app;
        }
    }
}
