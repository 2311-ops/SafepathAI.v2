using Microsoft.AspNetCore.SignalR;

namespace SafePath.Infrastructure.RealTime;

public class SupabaseUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) =>
        connection.User?.FindFirst("sub")?.Value ?? connection.User?.Identity?.Name;
}
