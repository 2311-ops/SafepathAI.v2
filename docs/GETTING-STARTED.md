# Getting Started

This guide gets the local backend and Flutter app running from a fresh clone.

## Prerequisites

- Git
- .NET SDK compatible with the backend projects
- Flutter SDK compatible with `mobile/pubspec.yaml`
- Android Studio or another Android toolchain if running on Android
- A Supabase project configured for the app
- Google OAuth clients configured for native Google sign-in

## Clone And Restore

```powershell
git clone https://github.com/2311-ops/SafepathAI.v2.git
cd safepathai_V2
```

Backend restore:

```powershell
cd backend
dotnet restore
```

Mobile restore:

```powershell
cd ..\mobile
flutter pub get
```

## Backend Configuration

Copy the backend environment template:

```powershell
cd ..\backend
copy .env.example .env
```

Fill in the local `backend/.env` values:

```text
ConnectionStrings__DefaultConnection=...
Supabase__Url=...
Supabase__Audience=authenticated
```

Keep `backend/.env` local. Do not commit it.

## Mobile Configuration

Create `mobile/env.json`:

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT-REF.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-SUPABASE-ANON-KEY",
  "GOOGLE_SERVER_CLIENT_ID": "YOUR-WEB-OAUTH-CLIENT-ID.apps.googleusercontent.com"
}
```

Keep `mobile/env.json` local. Do not commit it.

## Run The Backend

```powershell
cd backend
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

The HTTP launch profile listens on:

```text
http://localhost:5059
```

## Run The Mobile App

In another terminal:

```powershell
cd mobile
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

For Android USB device setup, use [../start_mobile.md](../start_mobile.md). It includes `adb reverse` commands for reaching the local backend through USB.

## First Manual Check

1. Start the backend.
2. Run the mobile app with `env.json` and `API_BASE_URL`.
3. Confirm the splash animation appears on cold launch.
4. Sign in with Google or email/password.
5. Confirm a new Google user without a role is sent to role selection.
6. Create or join a family circle.

## Troubleshooting

- If mobile auth works but `/me` or `/families/mine` fails, confirm `API_BASE_URL` points to the running backend.
- If a USB Android phone cannot reach the backend, run `adb reverse tcp:5059 tcp:5059`.
- If native Google sign-in shows a developer error, confirm the Android package name and debug SHA-1 are registered in Google Cloud.
- If backend tests cannot rebuild because DLLs are locked, stop the running API process and retry.
