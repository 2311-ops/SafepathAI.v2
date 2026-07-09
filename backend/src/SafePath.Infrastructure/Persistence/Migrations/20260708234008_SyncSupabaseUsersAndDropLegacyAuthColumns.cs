using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class SyncSupabaseUsersAndDropLegacyAuthColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.DropColumn(
                name: "PasswordHash",
                table: "Users");

            // Mobile signs up directly against Supabase Auth (auth.users) — nothing in this
            // app ever inserts into public."Users" anymore. This trigger mirrors every new
            // auth.users row into public."Users" so the app's own Users table (role,
            // full name) stays populated for backend features (MeController, future
            // family-circle work) to join against.
            migrationBuilder.Sql(
                """
                CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
                RETURNS trigger
                LANGUAGE plpgsql
                SECURITY DEFINER
                SET search_path = public
                AS $$
                BEGIN
                    INSERT INTO public."Users" ("Id", "Email", "FullName", "Role", "CreatedAt")
                    VALUES (
                        NEW.id,
                        NEW.email,
                        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
                        COALESCE(NEW.raw_user_meta_data ->> 'role', 'Member'),
                        NEW.created_at
                    )
                    ON CONFLICT ("Id") DO NOTHING;
                    RETURN NEW;
                END;
                $$;

                DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

                CREATE TRIGGER on_auth_user_created
                    AFTER INSERT ON auth.users
                    FOR EACH ROW
                    EXECUTE FUNCTION public.handle_new_auth_user();

                -- Backfill any accounts that signed up before this trigger existed.
                INSERT INTO public."Users" ("Id", "Email", "FullName", "Role", "CreatedAt")
                SELECT
                    au.id,
                    au.email,
                    COALESCE(au.raw_user_meta_data ->> 'full_name', ''),
                    COALESCE(au.raw_user_meta_data ->> 'role', 'Member'),
                    au.created_at
                FROM auth.users au
                ON CONFLICT ("Id") DO NOTHING;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
                DROP FUNCTION IF EXISTS public.handle_new_auth_user();
                """);

            migrationBuilder.AddColumn<string>(
                name: "PasswordHash",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    IsRevoked = table.Column<bool>(type: "boolean", nullable: false),
                    ReplacedFrom = table.Column<Guid>(type: "uuid", nullable: true),
                    Token = table.Column<string>(type: "text", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_Token",
                table: "RefreshTokens",
                column: "Token",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_UserId",
                table: "RefreshTokens",
                column: "UserId");
        }
    }
}
