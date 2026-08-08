using SafePath.Application.Common.Interfaces;
using SafePath.Application.Sos;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using SafePath.Infrastructure.Persistence;
using Xunit;

namespace SafePath.Application.Tests.Sos;

public class EmergencyContactCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task Add_NormalisesANationalNumberToE164()
    {
        await using var db = _factory.CreateContext();
        var ownerId = await SeedUser(db);
        var handler = new AddEmergencyContactCommandHandler(db);

        var result = await handler.Handle(new AddEmergencyContactCommand(ownerId, "Mom", "(202) 555-0182", "US"));

        Assert.StartsWith("+", result.PhoneNumberE164);
        Assert.True(result.PhoneNumberE164[1..].All(char.IsDigit));
    }

    [Fact]
    public async Task Add_RejectsAnUnparseableNumber()
    {
        await using var db = _factory.CreateContext();
        var ownerId = await SeedUser(db);
        var handler = new AddEmergencyContactCommandHandler(db);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            handler.Handle(new AddEmergencyContactCommand(ownerId, "Bad Contact", "not-a-number", "US")));

        Assert.Empty(db.EmergencyContacts);
    }

    [Fact]
    public async Task Add_ForcesOwnerToTheAuthenticatedCaller()
    {
        await using var db = _factory.CreateContext();
        var ownerId = await SeedUser(db);
        var handler = new AddEmergencyContactCommandHandler(db);

        var result = await handler.Handle(new AddEmergencyContactCommand(ownerId, "Mom", "(202) 555-0182", "US"));

        var stored = Assert.Single(db.EmergencyContacts);
        Assert.Equal(ownerId, stored.OwnerUserId);
        Assert.Equal(result.Id, stored.Id);
    }

    [Fact]
    public async Task List_ReturnsOnlyTheCallersOwnContacts()
    {
        await using var db = _factory.CreateContext();
        var ownerA = await SeedUser(db, "a@example.com");
        var ownerB = await SeedUser(db, "b@example.com");
        var addHandler = new AddEmergencyContactCommandHandler(db);
        await addHandler.Handle(new AddEmergencyContactCommand(ownerA, "A Contact", "(202) 555-0182", "US"));
        await addHandler.Handle(new AddEmergencyContactCommand(ownerB, "B Contact", "(202) 555-0183", "US"));

        var listHandler = new ListEmergencyContactsQueryHandler(db);
        var results = await listHandler.Handle(new ListEmergencyContactsQuery(ownerA));

        var contact = Assert.Single(results);
        Assert.Equal("A Contact", contact.DisplayName);
    }

    [Fact]
    public async Task Update_RejectsAContactOwnedBySomeoneElse()
    {
        await using var db = _factory.CreateContext();
        var ownerA = await SeedUser(db, "a@example.com");
        var ownerB = await SeedUser(db, "b@example.com");
        var addHandler = new AddEmergencyContactCommandHandler(db);
        var added = await addHandler.Handle(new AddEmergencyContactCommand(ownerA, "A Contact", "(202) 555-0182", "US"));

        var updateHandler = new UpdateEmergencyContactCommandHandler(db);

        await Assert.ThrowsAsync<FamilyAuthorizationDeniedException>(() =>
            updateHandler.Handle(new UpdateEmergencyContactCommand(ownerB, added.Id, "Hijacked", "(202) 555-0199", "US")));

        var stored = Assert.Single(db.EmergencyContacts);
        Assert.Equal("A Contact", stored.DisplayName);
    }

    [Fact]
    public async Task Delete_SoftDeactivatesRatherThanRemoving()
    {
        await using var db = _factory.CreateContext();
        var ownerId = await SeedUser(db);
        var addHandler = new AddEmergencyContactCommandHandler(db);
        var added = await addHandler.Handle(new AddEmergencyContactCommand(ownerId, "Mom", "(202) 555-0182", "US"));

        var deleteHandler = new DeleteEmergencyContactCommandHandler(db);
        await deleteHandler.Handle(new DeleteEmergencyContactCommand(ownerId, added.Id));

        var stored = Assert.Single(db.EmergencyContacts);
        Assert.False(stored.IsActive);
    }

    [Fact]
    public async Task List_ReturnsTheFullNumberToItsOwner()
    {
        await using var db = _factory.CreateContext();
        var ownerId = await SeedUser(db);
        var addHandler = new AddEmergencyContactCommandHandler(db);
        var added = await addHandler.Handle(new AddEmergencyContactCommand(ownerId, "Mom", "(202) 555-0182", "US"));

        var listHandler = new ListEmergencyContactsQueryHandler(db);
        var results = await listHandler.Handle(new ListEmergencyContactsQuery(ownerId));

        var contact = Assert.Single(results);
        Assert.Equal(added.PhoneNumberE164, contact.PhoneNumberE164);
        Assert.False(string.IsNullOrWhiteSpace(contact.PhoneNumberE164));
    }

    private static async Task<Guid> SeedUser(ApplicationDbContext db, string email = "owner@example.com")
    {
        var userId = Guid.NewGuid();
        db.Users.Add(new User { Id = userId, Email = email, FullName = "Owner", Role = Role.Member, CreatedAt = DateTime.UtcNow });
        await db.SaveChangesAsync();
        return userId;
    }

    public void Dispose() => _factory.Dispose();
}
