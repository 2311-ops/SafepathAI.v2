using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SafePath.Application.Common.Interfaces;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.Push;
using SafePath.Infrastructure.RealTime;
using SafePath.Infrastructure.Sms;
using SafePath.Infrastructure.Storage;

namespace SafePath.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

        services.AddScoped<IApplicationDbContext>(provider => provider.GetRequiredService<ApplicationDbContext>());

        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUserService, CurrentUserService>();
        services.AddScoped<IFamilyAuthorizationService, FamilyAuthorizationService>();
        services.AddScoped<ISharingAuthorizationService, SharingAuthorizationService>();
        services.AddScoped<IInviteCodeGenerator, InviteCodeGenerator>();
        services.AddSignalR();
        services.AddSingleton<IUserIdProvider, SupabaseUserIdProvider>();
        services.AddSingleton<PresenceTracker>();
        services.AddSingleton<IPresenceQuery>(provider => provider.GetRequiredService<PresenceTracker>());
        services.AddSingleton<LowBatteryAlertTracker>();
        services.AddSingleton<ILowBatteryAlertTracker>(provider => provider.GetRequiredService<LowBatteryAlertTracker>());
        services.AddScoped<ILocationBroadcastService, LocationBroadcastService>();
        services.AddScoped<IAlertBroadcastService, AlertBroadcastService>();
        services.AddHostedService<SharingPreferenceSweepService>();
        services.AddSingleton<IProfileImageValidator, ImageSharpProfileImageValidator>();
        services.AddHttpClient<IProfileImageStorage, SupabaseProfileImageStorage>((_, client) =>
        {
            var supabaseUrl = configuration["Supabase:Url"]
                ?? throw new InvalidOperationException("Supabase:Url is not configured.");
            var serviceRoleKey = configuration["Supabase:ServiceRoleKey"]
                ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");

            if (string.IsNullOrWhiteSpace(serviceRoleKey))
            {
                throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
            }

            client.BaseAddress = new Uri($"{supabaseUrl.TrimEnd('/')}/storage/v1/");
            client.DefaultRequestHeaders.Add("apikey", serviceRoleKey);

            if (serviceRoleKey.StartsWith("eyJ", StringComparison.Ordinal))
            {
                client.DefaultRequestHeaders.Authorization = new("Bearer", serviceRoleKey);
            }
        });

        var whatsAppOptions = new WhatsAppOptions
        {
            AccessToken = configuration["WhatsApp:AccessToken"],
            PhoneNumberId = configuration["WhatsApp:PhoneNumberId"],
            WabaId = configuration["WhatsApp:WabaId"],
            AppSecret = configuration["WhatsApp:AppSecret"],
            WebhookVerifyToken = configuration["WhatsApp:WebhookVerifyToken"],
            TemplateName = configuration["WhatsApp:TemplateName"] ?? "sos_alert",
            TemplateLanguage = configuration["WhatsApp:TemplateLanguage"] ?? "en",
            BaseUrl = configuration["WhatsApp:BaseUrl"] ?? "https://graph.facebook.com",
            ApiVersion = configuration["WhatsApp:ApiVersion"] ?? "v26.0",
        };
        services.AddSingleton(whatsAppOptions);

        // The default with no WhatsApp configuration present is LoggingSmsGateway (D-07) — a
        // fresh clone builds, tests, and demos the whole SOS pipeline with no WhatsApp Business
        // account and no cost. Logged once here (a throwaway bootstrap logger, since the DI
        // container has not been built yet at this point) so the operator is never confused
        // about why no real SMS arrived.
        using (var bootstrapLoggerFactory = LoggerFactory.Create(builder => builder.AddConsole()))
        {
            var bootstrapLogger = bootstrapLoggerFactory.CreateLogger("SafePath.Infrastructure.Sms");
            if (whatsAppOptions.IsConfigured)
            {
                bootstrapLogger.LogInformation("SMS gateway active: WhatsAppSmsGateway (WhatsApp credentials configured).");
            }
            else
            {
                bootstrapLogger.LogInformation("SMS gateway active: LoggingSmsGateway (no WhatsApp credentials configured — SMS sends are logged only, never sent).");
            }
        }

        if (whatsAppOptions.IsConfigured)
        {
            services.AddHttpClient<ISmsGateway, WhatsAppSmsGateway>(client =>
                client.BaseAddress = new Uri(whatsAppOptions.BaseUrl.TrimEnd('/') + "/"));
        }
        else
        {
            services.AddScoped<ISmsGateway, LoggingSmsGateway>();
        }

        services.AddScoped<ISmsWebhookSignatureValidator, WhatsAppWebhookSignatureValidator>();
        services.AddScoped<ISmsDeliveryStatusParser, WhatsAppDeliveryStatusParser>();

        var firebaseOptions = new FirebaseOptions
        {
            ProjectId = configuration["Firebase:ProjectId"],
            CredentialsPath = configuration["Firebase:CredentialsPath"],
        };
        services.AddSingleton(firebaseOptions);

        // The default with no Firebase configuration present is LoggingPushSender (D-07) — a
        // fresh clone builds, tests, and demos the whole SOS pipeline with no Firebase project
        // and no spend. Logged once here (a throwaway bootstrap logger, since the DI container
        // has not been built yet at this point) so the operator is never confused about why no
        // real push arrived.
        using (var bootstrapLoggerFactory = LoggerFactory.Create(builder => builder.AddConsole()))
        {
            var bootstrapLogger = bootstrapLoggerFactory.CreateLogger("SafePath.Infrastructure.Push");
            if (firebaseOptions.IsConfigured)
            {
                bootstrapLogger.LogInformation("Push sender active: FirebasePushSender (Firebase credentials configured).");
            }
            else
            {
                bootstrapLogger.LogInformation("Push sender active: LoggingPushSender (no Firebase credentials configured — push sends are logged only, never sent).");
            }
        }

        if (firebaseOptions.IsConfigured)
        {
            services.AddScoped<IPushSender, FirebasePushSender>();
        }
        else
        {
            services.AddScoped<IPushSender, LoggingPushSender>();
        }

        return services;
    }
}
