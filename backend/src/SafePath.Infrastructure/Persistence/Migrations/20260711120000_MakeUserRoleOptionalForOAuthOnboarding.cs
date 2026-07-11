using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SafePath.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MakeUserRoleOptionalForOAuthOnboarding : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Role",
                table: "Users",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

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
                        NULLIF(NEW.raw_user_meta_data ->> 'role', ''),
                        NEW.created_at
                    )
                    ON CONFLICT ("Id") DO UPDATE
                    SET
                        "Email" = EXCLUDED."Email",
                        "FullName" = CASE
                            WHEN EXCLUDED."FullName" <> '' THEN EXCLUDED."FullName"
                            ELSE public."Users"."FullName"
                        END,
                        "Role" = COALESCE(public."Users"."Role", EXCLUDED."Role");
                    RETURN NEW;
                END;
                $$;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE public."Users"
                SET "Role" = 'Member'
                WHERE "Role" IS NULL;

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
                """);

            migrationBuilder.AlterColumn<string>(
                name: "Role",
                table: "Users",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);
        }
    }
}
