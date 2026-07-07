namespace SafePath.Application.Common.Interfaces;

/// <summary>
/// Minimal hand-rolled command-dispatch abstraction (RESEARCH.md "Claude's discretion" —
/// chosen over Mediator.SourceGenerator / MediatR given this phase's small handler count;
/// avoids MediatR's v13+ commercial license-key requirement entirely, per locked decision
/// guidance in 01-01-PLAN.md).
/// </summary>
public interface ICommandHandler<in TCommand, TResult>
{
    Task<TResult> Handle(TCommand command, CancellationToken cancellationToken = default);
}
