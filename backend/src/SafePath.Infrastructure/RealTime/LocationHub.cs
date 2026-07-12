using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using SafePath.Application.Common.Interfaces;

namespace SafePath.Infrastructure.RealTime;

[Authorize]
public class LocationHub : Hub<ILocationClient>
{
    private readonly IFamilyAuthorizationService _authorization;
    private readonly PresenceTracker _presence;

    public LocationHub(IFamilyAuthorizationService authorization, PresenceTracker presence)
    {
        _authorization = authorization;
        _presence = presence;
    }

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        var familyId = GetFamilyIdFromQuery();

        await _authorization.RequireMembership(userId, familyId, Context.ConnectionAborted);

        var groupName = FamilyGroupName(familyId);
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName, Context.ConnectionAborted);

        var wasOffline = _presence.AddConnection(userId, Context.ConnectionId);
        if (wasOffline)
        {
            await Clients.OthersInGroup(groupName)
                .PresenceChanged(new PresenceChangeDto(userId, IsOnline: true));
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        if (Guid.TryParse(Context.UserIdentifier, out var userId))
        {
            var stillOnline = _presence.RemoveConnection(userId, Context.ConnectionId);
            if (!stillOnline && TryGetFamilyIdFromQuery(out var familyId))
            {
                await Clients.OthersInGroup(FamilyGroupName(familyId))
                    .PresenceChanged(new PresenceChangeDto(userId, IsOnline: false));
            }
        }

        await base.OnDisconnectedAsync(exception);
    }

    public static string FamilyGroupName(Guid familyId) => $"family:{familyId}";

    private Guid GetUserId()
    {
        if (Guid.TryParse(Context.UserIdentifier, out var userId))
        {
            return userId;
        }

        throw new HubException("Missing authenticated user.");
    }

    private Guid GetFamilyIdFromQuery()
    {
        if (TryGetFamilyIdFromQuery(out var familyId))
        {
            return familyId;
        }

        throw new HubException("A valid familyId query parameter is required.");
    }

    private bool TryGetFamilyIdFromQuery(out Guid familyId)
    {
        familyId = default;
        var rawFamilyId = Context.GetHttpContext()?.Request.Query["familyId"].ToString();
        return Guid.TryParse(rawFamilyId, out familyId);
    }
}
