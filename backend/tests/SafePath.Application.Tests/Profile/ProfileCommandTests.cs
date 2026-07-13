using SafePath.Application.Common.Interfaces;
using SafePath.Application.Families;
using SafePath.Application.Profile;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;
using SafePath.Domain.Enums;
using Xunit;

namespace SafePath.Application.Tests.Profile;

public class ProfileCommandTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public async Task UpdateDisplayName_TrimsAndStampsProfile()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId, fullName: "Original Name"));
        await db.SaveChangesAsync();

        var handler = new UpdateDisplayNameCommandHandler(db);

        var result = await handler.Handle(new UpdateDisplayNameCommand(userId, "  Map Name  "));

        var user = db.Users.Single(u => u.Id == userId);
        Assert.Equal("Map Name", user.DisplayName);
        Assert.NotNull(user.ProfileUpdatedAt);
        Assert.Equal("Map Name", result.DisplayName);
        Assert.Null(result.ProfileImageUrl);
        Assert.Equal(user.ProfileUpdatedAt, result.ProfileUpdatedAt);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task UpdateDisplayName_RejectsBlankNames(string displayName)
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId));
        await db.SaveChangesAsync();

        var handler = new UpdateDisplayNameCommandHandler(db);

        await Assert.ThrowsAsync<ArgumentException>(
            () => handler.Handle(new UpdateDisplayNameCommand(userId, displayName)));
    }

    [Fact]
    public async Task UpdateDisplayName_RejectsNamesOverEightyCharacters()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId));
        await db.SaveChangesAsync();

        var handler = new UpdateDisplayNameCommandHandler(db);

        await Assert.ThrowsAsync<ArgumentException>(
            () => handler.Handle(new UpdateDisplayNameCommand(userId, new string('A', 81))));
    }

    [Fact]
    public async Task UploadProfileImage_ValidatesBeforeStorageAndPersistsDeterministicPath()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId));
        await db.SaveChangesAsync();
        var calls = new List<string>();
        var storage = new FakeProfileImageStorage(calls);
        var validator = new FakeProfileImageValidator(calls);
        var handler = new UploadProfileImageCommandHandler(db, validator, storage);

        var result = await handler.Handle(new UploadProfileImageCommand(userId, [1, 2, 3]));

        var user = db.Users.Single(u => u.Id == userId);
        Assert.True(validator.Called);
        Assert.True(storage.UploadCalled);
        Assert.Equal(new[] { "validate", "upload" }, calls);
        Assert.Equal(storage.GetAvatarObjectPath(userId), user.ProfileImagePath);
        Assert.NotNull(user.ProfileUpdatedAt);
        Assert.Equal(storage.GetAvatarObjectPath(userId), storage.UploadedPath);
        Assert.Equal("signed://avatar", result.ProfileImageUrl);
    }

    [Fact]
    public async Task UploadProfileImage_PropagatesValidatorRejectionWithoutStorageWrite()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId));
        await db.SaveChangesAsync();
        var storage = new FakeProfileImageStorage();
        var validator = new FakeProfileImageValidator { Reject = true };
        var handler = new UploadProfileImageCommandHandler(db, validator, storage);

        await Assert.ThrowsAsync<ArgumentException>(
            () => handler.Handle(new UploadProfileImageCommand(userId, [9, 9, 9])));

        Assert.True(validator.Called);
        Assert.False(storage.UploadCalled);
    }

    [Fact]
    public async Task DeleteProfileImage_DeletesStorageObjectAndClearsPath()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId, profileImagePath: $"avatars/{userId}/avatar.jpg"));
        await db.SaveChangesAsync();
        var storage = new FakeProfileImageStorage();
        var handler = new DeleteProfileImageCommandHandler(db, storage);

        var result = await handler.Handle(new DeleteProfileImageCommand(userId));

        var user = db.Users.Single(u => u.Id == userId);
        Assert.True(storage.DeleteCalled);
        Assert.Null(user.ProfileImagePath);
        Assert.NotNull(user.ProfileUpdatedAt);
        Assert.Null(result.ProfileImageUrl);
    }

    [Fact]
    public async Task GetMe_ReturnsDisplayNameFallbackAndSignedProfileUrl()
    {
        await using var db = _factory.CreateContext();
        var userId = Guid.NewGuid();
        db.Users.Add(CreateUser(userId, fullName: "Fallback Name", profileImagePath: $"avatars/{userId}/avatar.jpg"));
        await db.SaveChangesAsync();
        var storage = new FakeProfileImageStorage();
        var handler = new GetMeQueryHandler(db, new ProfileImageUrlFactory(storage));

        var result = await handler.Handle(new GetMeQuery(userId));

        Assert.Equal("Fallback Name", result.DisplayName);
        Assert.Equal("signed://avatar", result.ProfileImageUrl);
        Assert.True(storage.SignCalled);
    }

    private static User CreateUser(Guid userId, string fullName = "Safe User", string? profileImagePath = null)
    {
        return new User
        {
            Id = userId,
            Email = $"{userId:N}@safepath.test",
            FullName = fullName,
            ProfileImagePath = profileImagePath,
            Role = Role.Member,
            CreatedAt = DateTime.UtcNow,
        };
    }

    public void Dispose() => _factory.Dispose();

    private sealed class FakeProfileImageValidator : IProfileImageValidator
    {
        private readonly List<string>? _calls;

        public FakeProfileImageValidator(List<string>? calls = null)
        {
            _calls = calls;
        }

        public bool Reject { get; init; }
        public bool Called { get; private set; }

        public ValidatedImage Validate(byte[] rawBytes)
        {
            Called = true;
            _calls?.Add("validate");
            if (Reject)
            {
                throw new ArgumentException("Invalid image.");
            }

            return new ValidatedImage([4, 5, 6], "image/jpeg");
        }
    }

    private sealed class FakeProfileImageStorage : IProfileImageStorage
    {
        private readonly List<string>? _calls;

        public FakeProfileImageStorage(List<string>? calls = null)
        {
            _calls = calls;
        }

        public bool UploadCalled { get; private set; }
        public bool DeleteCalled { get; private set; }
        public bool SignCalled { get; private set; }
        public string? UploadedPath { get; private set; }

        public Task UploadAvatarAsync(Guid userId, byte[] jpegBytes, CancellationToken cancellationToken = default)
        {
            UploadCalled = true;
            _calls?.Add("upload");
            UploadedPath = GetAvatarObjectPath(userId);
            return Task.CompletedTask;
        }

        public Task DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken = default)
        {
            DeleteCalled = true;
            return Task.CompletedTask;
        }

        public Task<string> CreateSignedAvatarUrlAsync(string objectPath, TimeSpan ttl, CancellationToken cancellationToken = default)
        {
            SignCalled = true;
            Assert.Equal(TimeSpan.FromHours(1), ttl);
            return Task.FromResult("signed://avatar");
        }

        public string GetAvatarObjectPath(Guid userId) => $"avatars/{userId}/avatar.jpg";
    }
}
