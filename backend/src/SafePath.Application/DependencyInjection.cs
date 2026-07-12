using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Location;
using SafePath.Application.Privacy;

namespace SafePath.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ICommandHandler<CreateFamilyCommand, Guid>, CreateFamilyCommandHandler>();
        services.AddScoped<ICommandHandler<ListFamilyMembersQuery, IReadOnlyList<FamilyMemberDto>>, ListFamilyMembersQueryHandler>();
        services.AddScoped<ICommandHandler<ListMyFamiliesQuery, IReadOnlyList<MyFamilyDto>>, ListMyFamiliesQueryHandler>();
        services.AddScoped<ICommandHandler<GenerateInviteCommand, GenerateInviteResult>, GenerateInviteCommandHandler>();
        services.AddScoped<ICommandHandler<RedeemInviteCommand, RedeemInviteResult>, RedeemInviteCommandHandler>();
        services.AddScoped<ICommandHandler<RevokeInviteCommand, RevokeInviteResult>, RevokeInviteCommandHandler>();
        services.AddScoped<ICommandHandler<UpdateMemberPermissionsCommand, UpdateMemberPermissionsResult>, UpdateMemberPermissionsCommandHandler>();
        services.AddScoped<ICommandHandler<RemoveMemberCommand, RemoveMemberResult>, RemoveMemberCommandHandler>();
        services.AddScoped<ICommandHandler<TransferOwnershipCommand, TransferOwnershipResult>, TransferOwnershipCommandHandler>();
        services.AddScoped<ICommandHandler<DeleteFamilyCommand, DeleteFamilyResult>, DeleteFamilyCommandHandler>();
        services.AddScoped<ICommandHandler<GetMeQuery, GetMeResult>, GetMeQueryHandler>();
        services.AddScoped<ICommandHandler<UpdateMyRoleCommand, GetMeResult>, UpdateMyRoleCommandHandler>();
        services.AddScoped<ICommandHandler<ReportLocationCommand, ReportLocationResult>, ReportLocationCommandHandler>();
        services.AddScoped<ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>>, GetLiveLocationsQueryHandler>();
        services.AddScoped<ICommandHandler<GetLocationHistoryQuery, LocationHistoryDto>, GetLocationHistoryQueryHandler>();
        services.AddScoped<ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto>, UpdateSharingPreferenceCommandHandler>();
        services.AddScoped<ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto>, GetSharingMatrixQueryHandler>();

        return services;
    }
}
