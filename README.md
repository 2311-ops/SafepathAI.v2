# SafePath AI

SafePath AI is a software-only family safety app. The repository currently contains:

- `mobile/` - Flutter app for Android and iOS.
- `backend/` - ASP.NET Core Web API using a Clean Architecture layout.
- `.planning/` - planning, phase, audit, and verification records.

The implemented foundation covers Supabase-owned authentication, role onboarding, family circle creation and invites, and the animated startup splash. Later roadmap work covers live location, SOS, geofencing, analytics, and health/wellness modules.

## Current State

Last documented: 2026-07-12.

| Area | State |
| --- | --- |
| Branch | `master` |
| Mobile | Flutter app with Riverpod, GoRouter, Supabase Auth, Dio, Google Sign-In, QR invites, and startup splash |
| Backend | ASP.NET Core 9 API with Supabase JWT validation, EF Core persistence, family/invite endpoints, and integration tests |
| Phase 1 | Backend & Auth Foundation verified |
| Phase 01.1 | Animated Logo Splash Screen verified |
| phase 2 | Phase 2: Real-Time Location, History & Privacy , done|

## Repository Layout

```text
.
├── backend/
│   ├── src/
│   │   ├── SafePath.Api/
│   │   ├── SafePath.Application/
│   │   ├── SafePath.Domain/
│   │   └── SafePath.Infrastructure/
│   └── tests/
├── mobile/
│   ├── lib/
│   └── test/
├── docs/
└── .planning/
```

## Quick Start

Backend:

```powershell
cd backend
dotnet restore
dotnet build SafePath.sln
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

Mobile:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

For USB Android setup, see [start_mobile.md](start_mobile.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Getting Started](docs/GETTING-STARTED.md)
- [Development](docs/DEVELOPMENT.md)
- [Testing](docs/TESTING.md)
- [Configuration](docs/CONFIGURATION.md)

## Verification

Mobile:

```powershell
cd mobile
flutter analyze
flutter test
```

Backend:

```powershell
cd backend
dotnet test SafePath.sln
```

If `dotnet test SafePath.sln` fails because the API DLLs are locked, stop the running `SafePath.Api` process and run the command again.

## Security Notes

- Do not commit local secrets, `.env` files, `mobile/env.json`, generated logs, screenshots with personal data, or OAuth client-secret JSON files.
- Supabase anon keys and Google client IDs are public client identifiers, but keep local environment files out of version control anyway.
- Backend connection strings belong in `backend/.env` or host environment variables, not tracked config.
