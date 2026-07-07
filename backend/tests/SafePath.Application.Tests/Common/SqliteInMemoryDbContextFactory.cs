using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SafePath.Infrastructure.Persistence;

namespace SafePath.Application.Tests.Common;

/// <summary>
/// Creates <see cref="ApplicationDbContext"/> instances backed by a single open, in-memory
/// SQLite connection. SQLite is used instead of the EF Core InMemory provider because
/// RefreshTokenCommand's reuse-detection wipe relies on ExecuteUpdateAsync, which the
/// InMemory provider does not support.
/// </summary>
public sealed class SqliteInMemoryDbContextFactory : IDisposable
{
    private readonly SqliteConnection _connection;

    public SqliteInMemoryDbContextFactory()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        using var context = CreateContext();
        context.Database.EnsureCreated();
    }

    public ApplicationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlite(_connection)
            .Options;

        return new ApplicationDbContext(options);
    }

    public void Dispose() => _connection.Dispose();
}
