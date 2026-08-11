using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using SafePath.Application.Tests.Common;
using SafePath.Domain.Entities;

namespace SafePath.Application.Tests.Geofencing;

public sealed class GeofencingSchemaTests : IDisposable
{
    private readonly SqliteInMemoryDbContextFactory _factory = new();

    [Fact]
    public void DurableGeofencingRecords_KeepHistoryAndDeliveryIndependentOfZoneDeletion()
    {
        using var db = _factory.CreateContext();
        var activity = db.Model.FindEntityType(typeof(GeofenceActivity));
        var feedItem = db.Model.FindEntityType(typeof(GeofenceFeedItem));
        var routineJob = db.Model.FindEntityType(typeof(GeofenceRoutineJob));

        Assert.NotNull(activity);
        Assert.NotNull(feedItem);
        Assert.NotNull(routineJob);
        Assert.NotNull(activity!.FindProperty(nameof(GeofenceActivity.VisitId)));
        Assert.NotNull(activity.FindProperty(nameof(GeofenceActivity.RetainUntilUtc)));
        Assert.NotNull(feedItem!.FindProperty(nameof(GeofenceFeedItem.ExpiresAtUtc)));
        Assert.NotNull(routineJob!.FindProperty(nameof(GeofenceRoutineJob.NextAttemptAtUtc)));

        var zoneForeignKey = activity.GetForeignKeys().Single(foreignKey => foreignKey.PrincipalEntityType.ClrType == typeof(SafeZone));
        Assert.Equal(DeleteBehavior.SetNull, zoneForeignKey.DeleteBehavior);
        Assert.Contains(activity.GetIndexes(), index =>
            index.Properties.Select(property => property.Name).SequenceEqual([
                nameof(GeofenceActivity.MemberUserId),
                nameof(GeofenceActivity.OccurredAtUtc)]));
    }

    [Fact]
    public void GeofencingUniquenessAndQuietHoursOwnership_AreEnforcedInTheEfModel()
    {
        using var db = _factory.CreateContext();

        AssertUniqueIndex(db.Model.FindEntityType(typeof(SafeZoneRegistration))!, nameof(SafeZoneRegistration.SafeZoneId), nameof(SafeZoneRegistration.Generation));
        AssertUniqueIndex(db.Model.FindEntityType(typeof(GeofenceCandidate))!, nameof(GeofenceCandidate.EventId));
        AssertUniqueIndex(db.Model.FindEntityType(typeof(GeofenceConfirmationCandidate))!,
            nameof(GeofenceConfirmationCandidate.SafeZoneId),
            nameof(GeofenceConfirmationCandidate.MemberUserId),
            nameof(GeofenceConfirmationCandidate.RegistrationGeneration),
            nameof(GeofenceConfirmationCandidate.IntendedTransition));
        AssertUniqueIndex(db.Model.FindEntityType(typeof(GeofenceFeedItem))!, nameof(GeofenceFeedItem.ActivityId), nameof(GeofenceFeedItem.RecipientUserId));
        AssertUniqueIndex(db.Model.FindEntityType(typeof(RecipientQuietHours))!, nameof(RecipientQuietHours.RecipientUserId));

        var quietHours = db.Model.FindEntityType(typeof(RecipientQuietHours))!;
        Assert.Equal(false, quietHours.FindProperty(nameof(RecipientQuietHours.IsEnabled))!.GetDefaultValue());
        Assert.NotNull(quietHours.FindProperty(nameof(RecipientQuietHours.LocalStart)));
        Assert.NotNull(quietHours.FindProperty(nameof(RecipientQuietHours.LocalEnd)));
        Assert.NotNull(quietHours.FindProperty(nameof(RecipientQuietHours.TimeZoneId)));
    }

    private static void AssertUniqueIndex(IEntityType entityType, params string[] propertyNames)
    {
        Assert.Contains(entityType.GetIndexes(), index =>
            index.IsUnique && index.Properties.Select(property => property.Name).SequenceEqual(propertyNames));
    }

    public void Dispose() => _factory.Dispose();
}
