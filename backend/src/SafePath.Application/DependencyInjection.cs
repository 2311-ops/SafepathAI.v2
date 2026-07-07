using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using SafePath.Application.Auth;
using SafePath.Application.Common.Interfaces;
using SafePath.Application.Common.Models;

namespace SafePath.Application;

public static class DependencyInjection
{
    /// <summary>
    /// Registers the hand-rolled auth command handlers + FluentValidation validators.
    /// No Mediator/MediatR dependency — a typed ICommandHandler&lt;TCommand,TResult&gt;
    /// per locked decision guidance (avoids MediatR's v13+ commercial license key).
    /// </summary>
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddScoped<ICommandHandler<RegisterCommand, AuthResult>, RegisterCommandHandler>();
        services.AddScoped<ICommandHandler<LoginCommand, AuthResult>, LoginCommandHandler>();
        services.AddScoped<ICommandHandler<RefreshTokenCommand, AuthResult>, RefreshTokenCommandHandler>();
        services.AddScoped<ICommandHandler<LogoutCommand, bool>, LogoutCommandHandler>();

        services.AddValidatorsFromAssemblyContaining<RegisterCommandValidator>();

        return services;
    }
}
