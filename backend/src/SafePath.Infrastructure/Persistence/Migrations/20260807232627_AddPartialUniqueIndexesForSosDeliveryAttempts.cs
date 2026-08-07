using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPartialUniqueIndexesForSosDeliveryAttempts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_RecipientUserId_EmergencyC~",
                table: "SosDeliveryAttempts");

            migrationBuilder.CreateIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_EmergencyContactId_Channel",
                table: "SosDeliveryAttempts",
                columns: new[] { "SosSessionId", "EmergencyContactId", "Channel" },
                unique: true,
                filter: "\"EmergencyContactId\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_RecipientUserId_Channel",
                table: "SosDeliveryAttempts",
                columns: new[] { "SosSessionId", "RecipientUserId", "Channel" },
                unique: true,
                filter: "\"RecipientUserId\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_EmergencyContactId_Channel",
                table: "SosDeliveryAttempts");

            migrationBuilder.DropIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_RecipientUserId_Channel",
                table: "SosDeliveryAttempts");

            migrationBuilder.CreateIndex(
                name: "IX_SosDeliveryAttempts_SosSessionId_RecipientUserId_EmergencyC~",
                table: "SosDeliveryAttempts",
                columns: new[] { "SosSessionId", "RecipientUserId", "EmergencyContactId", "Channel" },
                unique: true);
        }
    }
}
