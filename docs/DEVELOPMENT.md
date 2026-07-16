# Development

## Working Areas

Use `mobile/` for Flutter work and `backend/` for API/domain work. Planning and verification records live in `.planning/`.

## Mobile Development

Useful commands:

```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

Important directories:

- `lib/core/config` - Supabase and environment config.
- `lib/core/network` - Dio setup and auth retry behavior.
- `lib/core/router` - app routes and redirect rules.
- `lib/core/theme` - design tokens and ThemeData.
- `lib/features` - feature-specific state, data, and presentation code.
- `lib/shared_widgets` - reusable SafePath UI components.
- `test` - widget, routing, controller, and feature tests.

Follow the existing feature structure:

```text
features/<feature>/
  application/
  data/
  presentation/
```

## Backend Development

Useful commands:

```powershell
cd backend
dotnet restore
dotnet build SafePath.sln
dotnet test SafePath.sln
dotnet run --launch-profile http --project src\SafePath.Api\SafePath.Api.csproj
```

The default `http` profile binds `localhost` only (loopback), which is fine for the emulator and desktop. To test from a **physical device on the same Wi-Fi** (for example an Android phone hitting the host's LAN IP), start the backend with the `http-lan` profile, which binds `http://0.0.0.0:5059` so the host's LAN interface accepts connections:

```powershell
dotnet run --launch-profile http-lan --project src\SafePath.Api\SafePath.Api.csproj
```

Then build the mobile app against the host's LAN IP, e.g. `--dart-define=API_BASE_URL=http://<host-LAN-IP>:5059`, and confirm reachability from the host with `curl http://<host-LAN-IP>:5059/` (a 404 at `/` means Kestrel is listening). This profile is Development-only and does not affect the default profiles or production hosting. Ensure the host firewall allows inbound TCP 5059 on the private network.

### Physical device over USB (adb reverse) — preferred when the phone is on your desk

The LAN-IP approach above only works when the phone can actually reach the host over Wi-Fi. Many routers (and most guest/corporate networks) enable **Wi-Fi client isolation**, which blocks device-to-device traffic at layer 2 even when the phone and host share the same subnet — the symptom is `ping <host-LAN-IP>` from the phone returning `Destination Host Unreachable`. When that happens, use a USB tunnel instead of Wi-Fi:

```powershell
# phone connected via USB with debugging enabled
adb reverse tcp:5059 tcp:5059
```

This makes the device's own `127.0.0.1:5059` forward over the USB cable to the host's `127.0.0.1:5059`, so no Wi-Fi path is involved. Build the mobile app against loopback:

```powershell
cd mobile
flutter build apk --debug --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
flutter install -d <device-id> --debug --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
```

The backend can run under either profile for this (the tunnel targets host loopback, which every profile serves). Verify the tunnel from the device with `adb reverse --list` (expect `UsbFfs tcp:5059 tcp:5059`).

**Important:** `adb reverse` rules do **not** survive a USB disconnect or a device reboot — re-run `adb reverse tcp:5059 tcp:5059` at the start of each dev session (the app itself does not need rebuilding; only the tunnel must be re-armed).

**When to use which:**

- **USB tunnel (`adb reverse` + `API_BASE_URL=http://127.0.0.1:5059`)** — the reliable default when the phone is at the same desk and already cabled for `adb`/`flutter install`. Works regardless of Wi-Fi client isolation.
- **LAN IP (`http-lan` profile + `API_BASE_URL=http://<host-LAN-IP>:5059`)** — use for wireless-only setups (phone not cabled) on networks **without** AP/client isolation.

Project roles:

- `SafePath.Api` - HTTP boundary and startup wiring.
- `SafePath.Application` - use cases and interfaces.
- `SafePath.Domain` - entities and enums.
- `SafePath.Infrastructure` - database, identity, migrations, and infrastructure services.

Add new API behavior by keeping controller logic thin and placing business rules in application handlers.

## Database And Migrations

EF Core migrations are under:

```text
backend/src/SafePath.Infrastructure/Persistence/Migrations
```

The DbContext is:

```text
backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
```

Use `backend/.env` or host environment variables for `ConnectionStrings__DefaultConnection`.

## Routing And Auth Notes

The mobile router handles:

- startup splash gating
- signed-in vs signed-out routes
- password recovery
- Google users who still need role onboarding
- pending invite restoration

When changing auth or navigation, run the router and auth tests before manual device testing.

## Style Guidelines

- Keep code changes close to the existing architecture.
- Use Riverpod providers for mobile state and service wiring.
- Use shared SafePath widgets and theme tokens for UI consistency.
- Do not duplicate Google sign-in logic; use `GoogleSignInButton`.
- Keep backend command/query handlers focused and testable.

## Local Files To Keep Private

Do not commit:

- `mobile/env.json`
- `backend/.env`
- `client_secret_*.json`
- logs such as `*.log`
- screenshots or user data captures
- build outputs
