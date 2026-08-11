using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddGeofencing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RecipientQuietHours",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    LocalStart = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    LocalEnd = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    TimeZoneId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecipientQuietHours", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecipientQuietHours_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            // The prior tracer migration owns these four tables. Its snapshot was not advanced,
            // so EF's generated diff included duplicate CreateTable operations. Keep EF's final
            // generated snapshot, but apply only the new constraints to the existing tables.
            migrationBuilder.AddCheckConstraint(
                name: "CK_SafeZones_Category",
                table: "SafeZones",
                sql: "\"Category\" BETWEEN 0 AND 4");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SafeZones_Sensitivity",
                table: "SafeZones",
                sql: "\"Sensitivity\" BETWEEN 0 AND 2");

            migrationBuilder.AddCheckConstraint(
                name: "CK_GeofenceCandidates_Generation",
                table: "GeofenceCandidates",
                sql: "\"RegistrationGeneration\" > 0");

            migrationBuilder.AddCheckConstraint(
                name: "CK_GeofenceCandidates_Transition",
                table: "GeofenceCandidates",
                sql: "\"Transition\" BETWEEN 0 AND 1");

            migrationBuilder.AddCheckConstraint(
                name: "CK_SafeZoneRegistrations_Generation",
                table: "SafeZoneRegistrations",
                sql: "\"Generation\" > 0");

            migrationBuilder.CreateTable(
                name: "GeofenceActivities",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SafeZoneId = table.Column<Guid>(type: "uuid", nullable: true),
                    SafeZoneDisplayName = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    MemberUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Transition = table.Column<int>(type: "integer", nullable: false),
                    VisitId = table.Column<Guid>(type: "uuid", nullable: true),
                    CompletedVisitDurationSeconds = table.Column<int>(type: "integer", nullable: true),
                    OccurredAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RecordedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RetainUntilUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeofenceActivities", x => x.Id);
                    table.CheckConstraint("CK_GeofenceActivities_Transition", "\"Transition\" BETWEEN 0 AND 1");
                    table.ForeignKey(
                        name: "FK_GeofenceActivities_SafeZones_SafeZoneId",
                        column: x => x.SafeZoneId,
                        principalTable: "SafeZones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_GeofenceActivities_Users_MemberUserId",
                        column: x => x.MemberUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "GeofenceConfirmationCandidates",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SafeZoneId = table.Column<Guid>(type: "uuid", nullable: false),
                    MemberUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RegistrationGeneration = table.Column<int>(type: "integer", nullable: false),
                    IntendedTransition = table.Column<int>(type: "integer", nullable: false),
                    State = table.Column<int>(type: "integer", nullable: false),
                    FirstObservedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastObservedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeofenceConfirmationCandidates", x => x.Id);
                    table.CheckConstraint("CK_GeofenceConfirmationCandidates_Generation", "\"RegistrationGeneration\" > 0");
                    table.CheckConstraint("CK_GeofenceConfirmationCandidates_State", "\"State\" BETWEEN 0 AND 3");
                    table.CheckConstraint("CK_GeofenceConfirmationCandidates_Transition", "\"IntendedTransition\" BETWEEN 0 AND 1");
                    table.ForeignKey(
                        name: "FK_GeofenceConfirmationCandidates_SafeZones_SafeZoneId",
                        column: x => x.SafeZoneId,
                        principalTable: "SafeZones",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GeofenceConfirmationCandidates_Users_MemberUserId",
                        column: x => x.MemberUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "GeofenceFeedItems",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ActivityId = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ReadAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeofenceFeedItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GeofenceFeedItems_GeofenceActivities_ActivityId",
                        column: x => x.ActivityId,
                        principalTable: "GeofenceActivities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GeofenceFeedItems_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SafeZoneRegistrationActivations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    SafeZoneRegistrationId = table.Column<Guid>(type: "uuid", nullable: false),
                    State = table.Column<int>(type: "integer", nullable: false),
                    StateChangedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    FailureReason = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SafeZoneRegistrationActivations", x => x.Id);
                    table.CheckConstraint("CK_SafeZoneRegistrationActivations_State", "\"State\" BETWEEN 0 AND 3");
                    table.ForeignKey(
                        name: "FK_SafeZoneRegistrationActivations_SafeZoneRegistrations_SafeZ~",
                        column: x => x.SafeZoneRegistrationId,
                        principalTable: "SafeZoneRegistrations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "GeofenceRoutineJobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FeedItemId = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    State = table.Column<int>(type: "integer", nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    NextAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastAttemptAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastFailureReason = table.Column<string>(type: "character varying(512)", maxLength: 512, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeofenceRoutineJobs", x => x.Id);
                    table.CheckConstraint("CK_GeofenceRoutineJobs_State", "\"State\" BETWEEN 0 AND 5");
                    table.ForeignKey(
                        name: "FK_GeofenceRoutineJobs_GeofenceFeedItems_FeedItemId",
                        column: x => x.FeedItemId,
                        principalTable: "GeofenceFeedItems",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GeofenceRoutineJobs_Users_RecipientUserId",
                        column: x => x.RecipientUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceActivities_MemberUserId_OccurredAtUtc",
                table: "GeofenceActivities",
                columns: new[] { "MemberUserId", "OccurredAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceActivities_RetainUntilUtc",
                table: "GeofenceActivities",
                column: "RetainUntilUtc");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceActivities_SafeZoneId",
                table: "GeofenceActivities",
                column: "SafeZoneId");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceActivities_VisitId",
                table: "GeofenceActivities",
                column: "VisitId");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceConfirmationCandidates_MemberUserId",
                table: "GeofenceConfirmationCandidates",
                column: "MemberUserId");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceConfirmationCandidates_SafeZoneId_MemberUserId_Regi~",
                table: "GeofenceConfirmationCandidates",
                columns: new[] { "SafeZoneId", "MemberUserId", "RegistrationGeneration", "IntendedTransition" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceConfirmationCandidates_State_LastObservedAtUtc",
                table: "GeofenceConfirmationCandidates",
                columns: new[] { "State", "LastObservedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceFeedItems_ActivityId_RecipientUserId",
                table: "GeofenceFeedItems",
                columns: new[] { "ActivityId", "RecipientUserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceFeedItems_ExpiresAtUtc",
                table: "GeofenceFeedItems",
                column: "ExpiresAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceFeedItems_RecipientUserId_CreatedAtUtc",
                table: "GeofenceFeedItems",
                columns: new[] { "RecipientUserId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceRoutineJobs_ExpiresAtUtc",
                table: "GeofenceRoutineJobs",
                column: "ExpiresAtUtc");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceRoutineJobs_FeedItemId",
                table: "GeofenceRoutineJobs",
                column: "FeedItemId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceRoutineJobs_RecipientUserId",
                table: "GeofenceRoutineJobs",
                column: "RecipientUserId");

            migrationBuilder.CreateIndex(
                name: "IX_GeofenceRoutineJobs_State_NextAttemptAtUtc",
                table: "GeofenceRoutineJobs",
                columns: new[] { "State", "NextAttemptAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RecipientQuietHours_RecipientUserId",
                table: "RecipientQuietHours",
                column: "RecipientUserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SafeZoneRegistrationActivations_SafeZoneRegistrationId",
                table: "SafeZoneRegistrationActivations",
                column: "SafeZoneRegistrationId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SafeZoneRegistrationActivations_State_StateChangedAtUtc",
                table: "SafeZoneRegistrationActivations",
                columns: new[] { "State", "StateChangedAtUtc" });

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GeofenceRoutineJobs");

            migrationBuilder.DropTable(
                name: "SafeZoneRegistrationActivations");

            migrationBuilder.DropTable(
                name: "GeofenceFeedItems");

            migrationBuilder.DropTable(
                name: "GeofenceConfirmationCandidates");

            migrationBuilder.DropTable(
                name: "RecipientQuietHours");

            migrationBuilder.DropTable(
                name: "GeofenceActivities");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SafeZones_Category",
                table: "SafeZones");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SafeZones_Sensitivity",
                table: "SafeZones");

            migrationBuilder.DropCheckConstraint(
                name: "CK_GeofenceCandidates_Generation",
                table: "GeofenceCandidates");

            migrationBuilder.DropCheckConstraint(
                name: "CK_GeofenceCandidates_Transition",
                table: "GeofenceCandidates");

            migrationBuilder.DropCheckConstraint(
                name: "CK_SafeZoneRegistrations_Generation",
                table: "SafeZoneRegistrations");
        }
    }
}
