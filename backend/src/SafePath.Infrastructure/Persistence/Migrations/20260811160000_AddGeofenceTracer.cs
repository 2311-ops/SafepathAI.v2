using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations;

[DbContext(typeof(ApplicationDbContext))]
[Migration("20260811160000_AddGeofenceTracer")]
/// <summary>Durable, normalized storage for the Phase 4 tracer before confirmation/activity expansion.</summary>
public partial class AddGeofenceTracer : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "SafeZones",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                AssignedMemberUserId = table.Column<Guid>(type: "uuid", nullable: false),
                CreatedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                Category = table.Column<int>(type: "integer", nullable: false),
                CustomName = table.Column<string>(type: "text", nullable: true),
                Latitude = table.Column<double>(type: "double precision", nullable: false),
                Longitude = table.Column<double>(type: "double precision", nullable: false),
                RadiusMeters = table.Column<double>(type: "double precision", nullable: false),
                Sensitivity = table.Column<int>(type: "integer", nullable: false),
                NotifyAssignedMember = table.Column<bool>(type: "boolean", nullable: false),
                CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                IsActive = table.Column<bool>(type: "boolean", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SafeZones", x => x.Id);
                table.ForeignKey("FK_SafeZones_Families_FamilyId", x => x.FamilyId, "Families", "Id", onDelete: ReferentialAction.Cascade);
                table.ForeignKey("FK_SafeZones_Users_AssignedMemberUserId", x => x.AssignedMemberUserId, "Users", "Id", onDelete: ReferentialAction.Restrict);
                table.ForeignKey("FK_SafeZones_Users_CreatedByUserId", x => x.CreatedByUserId, "Users", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "SafeZoneRecipients",
            columns: table => new
            {
                SafeZoneId = table.Column<Guid>(type: "uuid", nullable: false),
                RecipientUserId = table.Column<Guid>(type: "uuid", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SafeZoneRecipients", x => new { x.SafeZoneId, x.RecipientUserId });
                table.ForeignKey("FK_SafeZoneRecipients_SafeZones_SafeZoneId", x => x.SafeZoneId, "SafeZones", "Id", onDelete: ReferentialAction.Cascade);
                table.ForeignKey("FK_SafeZoneRecipients_Users_RecipientUserId", x => x.RecipientUserId, "Users", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "SafeZoneRegistrations",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                SafeZoneId = table.Column<Guid>(type: "uuid", nullable: false),
                MemberUserId = table.Column<Guid>(type: "uuid", nullable: false),
                Generation = table.Column<int>(type: "integer", nullable: false),
                IssuedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                AcknowledgedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SafeZoneRegistrations", x => x.Id);
                table.ForeignKey("FK_SafeZoneRegistrations_SafeZones_SafeZoneId", x => x.SafeZoneId, "SafeZones", "Id", onDelete: ReferentialAction.Cascade);
                table.ForeignKey("FK_SafeZoneRegistrations_Users_MemberUserId", x => x.MemberUserId, "Users", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateTable(
            name: "GeofenceCandidates",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uuid", nullable: false),
                EventId = table.Column<Guid>(type: "uuid", nullable: false),
                SafeZoneId = table.Column<Guid>(type: "uuid", nullable: false),
                MemberUserId = table.Column<Guid>(type: "uuid", nullable: false),
                RegistrationGeneration = table.Column<int>(type: "integer", nullable: false),
                Transition = table.Column<int>(type: "integer", nullable: false),
                OccurredAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                Latitude = table.Column<double>(type: "double precision", nullable: false),
                Longitude = table.Column<double>(type: "double precision", nullable: false),
                AccuracyMeters = table.Column<double>(type: "double precision", nullable: false),
                ReceivedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_GeofenceCandidates", x => x.Id);
                table.ForeignKey("FK_GeofenceCandidates_SafeZones_SafeZoneId", x => x.SafeZoneId, "SafeZones", "Id", onDelete: ReferentialAction.Cascade);
                table.ForeignKey("FK_GeofenceCandidates_Users_MemberUserId", x => x.MemberUserId, "Users", "Id", onDelete: ReferentialAction.Restrict);
            });

        migrationBuilder.CreateIndex(name: "IX_SafeZones_AssignedMemberUserId", table: "SafeZones", column: "AssignedMemberUserId");
        migrationBuilder.CreateIndex(name: "IX_SafeZones_CreatedByUserId", table: "SafeZones", column: "CreatedByUserId");
        migrationBuilder.CreateIndex(name: "IX_SafeZones_FamilyId_AssignedMemberUserId_IsActive", table: "SafeZones", columns: new[] { "FamilyId", "AssignedMemberUserId", "IsActive" });
        migrationBuilder.CreateIndex(name: "IX_SafeZoneRecipients_RecipientUserId", table: "SafeZoneRecipients", column: "RecipientUserId");
        migrationBuilder.CreateIndex(name: "IX_SafeZoneRegistrations_MemberUserId", table: "SafeZoneRegistrations", column: "MemberUserId");
        migrationBuilder.CreateIndex(name: "IX_SafeZoneRegistrations_SafeZoneId_Generation", table: "SafeZoneRegistrations", columns: new[] { "SafeZoneId", "Generation" }, unique: true);
        migrationBuilder.CreateIndex(name: "IX_GeofenceCandidates_EventId", table: "GeofenceCandidates", column: "EventId", unique: true);
        migrationBuilder.CreateIndex(name: "IX_GeofenceCandidates_MemberUserId", table: "GeofenceCandidates", column: "MemberUserId");
        migrationBuilder.CreateIndex(name: "IX_GeofenceCandidates_SafeZoneId_MemberUserId_OccurredAtUtc", table: "GeofenceCandidates", columns: new[] { "SafeZoneId", "MemberUserId", "OccurredAtUtc" });
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "GeofenceCandidates");
        migrationBuilder.DropTable(name: "SafeZoneRecipients");
        migrationBuilder.DropTable(name: "SafeZoneRegistrations");
        migrationBuilder.DropTable(name: "SafeZones");
    }
}
