using SafePath.Application.Common;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Location;
using SafePath.Application.Profile;
using SafePath.Application.Privacy;
using SafePath.Application.Sos;
using SafePath.Application.Geofencing;

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
        services.AddScoped<ProfileImageUrlFactory>();
        services.AddScoped<ICommandHandler<UpdateDisplayNameCommand, GetMeResult>, UpdateDisplayNameCommandHandler>();
        services.AddScoped<ICommandHandler<UpdatePhoneNumberCommand, GetMeResult>, UpdatePhoneNumberCommandHandler>();
        services.AddScoped<ICommandHandler<UploadProfileImageCommand, GetMeResult>, UploadProfileImageCommandHandler>();
        services.AddScoped<ICommandHandler<DeleteProfileImageCommand, GetMeResult>, DeleteProfileImageCommandHandler>();
        services.AddScoped<ICommandHandler<ReportLocationCommand, ReportLocationResult>, ReportLocationCommandHandler>();
        services.AddScoped<ICommandHandler<GetLiveLocationsQuery, IReadOnlyList<MemberLiveLocationDto>>, GetLiveLocationsQueryHandler>();
        services.AddScoped<ICommandHandler<GetLocationHistoryQuery, LocationHistoryDto>, GetLocationHistoryQueryHandler>();
        services.AddScoped<ICommandHandler<GetTravelStatsQuery, TravelStatsDto>, GetTravelStatsQueryHandler>();
        services.AddScoped<ICommandHandler<UpdateSharingPreferenceCommand, SharingPreferenceDto>, UpdateSharingPreferenceCommandHandler>();
        services.AddScoped<ICommandHandler<GetSharingMatrixQuery, SharingMatrixDto>, GetSharingMatrixQueryHandler>();
        services.AddScoped<ICommandHandler<ExportMyDataQuery, MyDataExportDto>, ExportMyDataQueryHandler>();
        services.AddScoped<ICommandHandler<DeleteMyDataCommand, DeleteMyDataResult>, DeleteMyDataCommandHandler>();
        services.AddSingleton(sp =>
        {
            // Sos:LiveWindowMinutes, default 15 (same "no config = safe default" shape as
            // FirebaseOptions/TextBeeOptions) — lets a demo shorten the live-location window
            // without a rebuild. IConfiguration is registered by the host automatically, so this
            // does not require widening AddApplication's own signature.
            var configuration = sp.GetService<IConfiguration>();
            var configuredMinutes = configuration?["Sos:LiveWindowMinutes"];
            var liveWindowMinutes = int.TryParse(configuredMinutes, out var parsed) ? parsed : 15;
            return new SosLiveWindowOptions { LiveWindowMinutes = liveWindowMinutes };
        });
        services.AddScoped<ISosAlertDispatcher, SosAlertDispatcher>();
        services.AddScoped<ICommandHandler<TriggerSosCommand, TriggerSosResult>, TriggerSosCommandHandler>();
        services.AddScoped<ICommandHandler<GetSosSessionQuery, GetSosSessionResult>, GetSosSessionQueryHandler>();
        services.AddScoped<ICommandHandler<AcknowledgeSosCommand, AcknowledgeSosResult>, AcknowledgeSosCommandHandler>();
        services.AddScoped<ICommandHandler<CancelSosCommand, CancelSosResult>, CancelSosCommandHandler>();
        services.AddScoped<ICommandHandler<ReportSosLocationCommand, ReportSosLocationResult>, ReportSosLocationCommandHandler>();
        services.AddScoped<ICommandHandler<AddEmergencyContactCommand, EmergencyContactDto>, AddEmergencyContactCommandHandler>();
        services.AddScoped<ICommandHandler<UpdateEmergencyContactCommand, EmergencyContactDto>, UpdateEmergencyContactCommandHandler>();
        services.AddScoped<ICommandHandler<DeleteEmergencyContactCommand, EmergencyContactDto>, DeleteEmergencyContactCommandHandler>();
        services.AddScoped<ICommandHandler<ListEmergencyContactsQuery, IReadOnlyList<EmergencyContactDto>>, ListEmergencyContactsQueryHandler>();
        services.AddScoped<ICommandHandler<RecordSmsDeliveryStatusCommand, RecordSmsDeliveryStatusResult>, RecordSmsDeliveryStatusCommandHandler>();
        services.AddScoped<ICommandHandler<RegisterDeviceTokenCommand, RegisterDeviceTokenResult>, RegisterDeviceTokenCommandHandler>();
        services.AddScoped<ICommandHandler<RemoveDeviceTokenCommand, bool>, RemoveDeviceTokenCommandHandler>();
        services.AddScoped<ICommandHandler<ConfirmPushReceiptCommand, ConfirmPushReceiptResult>, ConfirmPushReceiptCommandHandler>();
        services.AddScoped<ICommandHandler<CreateSafeZoneCommand, CreateSafeZoneResult>, CreateSafeZoneCommandHandler>();
        services.AddScoped<ICommandHandler<GetMySafeZoneRegistrationQuery, SafeZoneRegistrationDto?>, GetMySafeZoneRegistrationQueryHandler>();
        services.AddScoped<ICommandHandler<AcknowledgeSafeZoneRegistrationCommand, bool>, AcknowledgeSafeZoneRegistrationCommandHandler>();
        services.AddScoped<ICommandHandler<SubmitGeofenceCandidateCommand, SubmitGeofenceCandidateResult>, SubmitGeofenceCandidateCommandHandler>();

        return services;
    }
}
