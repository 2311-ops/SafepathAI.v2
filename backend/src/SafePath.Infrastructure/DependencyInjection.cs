using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Common.Interfaces;
using SafePath.Infrastructure.Identity;
using SafePath.Infrastructure.Persistence;
using SafePath.Infrastructure.RealTime;

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
        services.AddHostedService<SharingPreferenceSweepService>();

        return services;
    }
}
