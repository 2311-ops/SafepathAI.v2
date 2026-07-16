# Configuration

SafePath uses local environment files for development and host-provided environment variables outside local development.

## Backend Configuration

Template:

```text
backend/.env.example
```

Local file:

```text
backend/.env
```

Required keys:

| Key | Purpose |
| --- | --- |
| `ConnectionStrings__DefaultConnection` | Postgres/Supabase database connection used by EF Core |
| `Supabase__Url` | Supabase project URL |
| `Supabase__Audience` | JWT audience, usually `authenticated` |

`SafePath.Api/Program.cs` loads `.env` with DotNetEnv if a local file exists. ASP.NET Core maps double-underscore keys to nested configuration values.

Tracked backend config files keep real secrets out of git:

- `backend/.env.example` contains placeholders.
- `backend/src/SafePath.Api/appsettings.json` documents that `DefaultConnection` is injected externally.
- `backend/src/SafePath.Api/Properties/launchSettings.json` defines local HTTP/HTTPS launch profiles.

## Mobile Configuration

Local file:

```text
mobile/env.json
```

Required keys:

| Key | Purpose |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL for the Flutter client |
| `SUPABASE_ANON_KEY` | Supabase anon client key |
| `GOOGLE_SERVER_CLIENT_ID` | Google Web OAuth client ID used by native Google sign-in |

Pass the file at run/build time:

```powershell
cd mobile
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

The app reads these values in:

```text
mobile/lib/core/config/supabase_config.dart
```

## API Base URL

The Flutter API client reads `API_BASE_URL` from a Dart define in:

```text
mobile/lib/core/network/dio_client.dart
```

Common values:

| Environment | Value |
| --- | --- |
| Android emulator | `http://10.0.2.2:5059` |
| USB Android with `adb reverse` | `http://127.0.0.1:5059` |
| Physical device over Wi-Fi | `http://<PC-LAN-IP>:5059` |

## Google Sign-In Configuration

Native Google sign-in requires Google Cloud OAuth clients that match the app package and signing certificates.

Development checks:

- `GOOGLE_SERVER_CLIENT_ID` is the Web OAuth client ID used with Supabase.
- Android OAuth client registration must include the app package and debug SHA-1.
- Release builds need release signing SHA registration too.

## Deep Links

The app uses the `safepathai://` scheme for flows such as password recovery and invite links. Android and iOS platform files must keep that scheme registered when deep-link behavior changes.

## Files That Must Stay Local

Do not commit:

- `mobile/env.json`
- `backend/.env`
- OAuth client-secret JSON files
- generated logs
- personal screenshots or captures

If a secret is accidentally committed, rotate it in the provider dashboard and remove it from git history as a separate security cleanup.
