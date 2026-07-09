using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;

namespace SafePath.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ICommandHandler<CreateFamilyCommand, Guid>, CreateFamilyCommandHandler>();
        services.AddScoped<ICommandHandler<ListFamilyMembersQuery, IReadOnlyList<FamilyMemberDto>>, ListFamilyMembersQueryHandler>();
        services.AddScoped<ICommandHandler<GenerateInviteCommand, GenerateInviteResult>, GenerateInviteCommandHandler>();
        services.AddScoped<ICommandHandler<RedeemInviteCommand, RedeemInviteResult>, RedeemInviteCommandHandler>();

        return services;
    }
}
