namespace SafePath.Application.Common.Interfaces;

public interface IPresenceQuery
{
    bool IsOnline(Guid userId);
}
