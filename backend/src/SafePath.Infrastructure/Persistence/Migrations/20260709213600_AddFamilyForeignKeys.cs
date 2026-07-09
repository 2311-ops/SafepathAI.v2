using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddFamilyForeignKeys : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DELETE FROM \"FamilyMembers\" WHERE \"FamilyId\" NOT IN (SELECT \"Id\" FROM \"Families\");");
            migrationBuilder.Sql("DELETE FROM \"FamilyInvitations\" WHERE \"FamilyId\" NOT IN (SELECT \"Id\" FROM \"Families\");");

            migrationBuilder.CreateIndex(
                name: "IX_FamilyMembers_UserId",
                table: "FamilyMembers",
                column: "UserId",
                unique: true,
                filter: "\"IsActive\" = TRUE");

            migrationBuilder.CreateIndex(
                name: "IX_FamilyInvitations_FamilyId",
                table: "FamilyInvitations",
                column: "FamilyId");

            migrationBuilder.AddForeignKey(
                name: "FK_FamilyInvitations_Families_FamilyId",
                table: "FamilyInvitations",
                column: "FamilyId",
                principalTable: "Families",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_FamilyMembers_Families_FamilyId",
                table: "FamilyMembers",
                column: "FamilyId",
                principalTable: "Families",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.Sql("ALTER TABLE \"Families\" ENABLE ROW LEVEL SECURITY;");
            migrationBuilder.Sql("ALTER TABLE \"FamilyMembers\" ENABLE ROW LEVEL SECURITY;");
            migrationBuilder.Sql("ALTER TABLE \"FamilyInvitations\" ENABLE ROW LEVEL SECURITY;");
            migrationBuilder.Sql("REVOKE ALL ON TABLE \"Families\" FROM anon, authenticated;");
            migrationBuilder.Sql("REVOKE ALL ON TABLE \"FamilyMembers\" FROM anon, authenticated;");
            migrationBuilder.Sql("REVOKE ALL ON TABLE \"FamilyInvitations\" FROM anon, authenticated;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("ALTER TABLE \"FamilyInvitations\" DISABLE ROW LEVEL SECURITY;");
            migrationBuilder.Sql("ALTER TABLE \"FamilyMembers\" DISABLE ROW LEVEL SECURITY;");
            migrationBuilder.Sql("ALTER TABLE \"Families\" DISABLE ROW LEVEL SECURITY;");

            migrationBuilder.DropForeignKey(
                name: "FK_FamilyInvitations_Families_FamilyId",
                table: "FamilyInvitations");

            migrationBuilder.DropForeignKey(
                name: "FK_FamilyMembers_Families_FamilyId",
                table: "FamilyMembers");

            migrationBuilder.DropIndex(
                name: "IX_FamilyMembers_UserId",
                table: "FamilyMembers");

            migrationBuilder.DropIndex(
                name: "IX_FamilyInvitations_FamilyId",
                table: "FamilyInvitations");
        }
    }
}
