using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddSharingPreference : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SharingPreferences",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientMemberId = table.Column<Guid>(type: "uuid", nullable: true),
                    DataType = table.Column<string>(type: "text", nullable: false),
                    IsEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SharingPreferences", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SharingPreferences_Families_FamilyId",
                        column: x => x.FamilyId,
                        principalTable: "Families",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_SharingPreferences_FamilyMembers_RecipientMemberId",
                        column: x => x.RecipientMemberId,
                        principalTable: "FamilyMembers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SharingPreferences_FamilyId_OwnerUserId",
                table: "SharingPreferences",
                columns: new[] { "FamilyId", "OwnerUserId" });

            migrationBuilder.CreateIndex(
                name: "IX_SharingPreferences_OwnerUserId_DataType",
                table: "SharingPreferences",
                columns: new[] { "OwnerUserId", "DataType" });

            migrationBuilder.CreateIndex(
                name: "IX_SharingPreferences_RecipientMemberId",
                table: "SharingPreferences",
                column: "RecipientMemberId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SharingPreferences");
        }
    }
}
