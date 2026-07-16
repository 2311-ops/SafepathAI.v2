# Testing

## Mobile Tests

Run all mobile checks:

```powershell
cd mobile
flutter analyze
flutter test
```

The current mobile suite covers:

- auth state and navigation
- register/login/password reset screens
- role selection
- Google sign-in button behavior
- family invite and acceptance flows
- startup splash animation and router gate
- theme tokens and app smoke tests

Focused examples:

```powershell
cd mobile
flutter test test/features/auth/register_screen_test.dart
flutter test test/features/splash/splash_screen_test.dart test/features/splash/splash_redirect_gate_test.dart
```

## Backend Tests

Run the full backend solution:

```powershell
cd backend
dotnet test SafePath.sln
```

Targeted backend tests:

```powershell
cd ..
dotnet test backend\tests\SafePath.Application.Tests\SafePath.Application.Tests.csproj --no-build --no-restore
dotnet test backend\tests\SafePath.Api.IntegrationTests\SafePath.Api.IntegrationTests.csproj --no-build --no-restore
```

If the full solution test fails with locked DLL copy errors, stop the running `SafePath.Api` process and rerun the command.

## Manual Device Checks

Use a physical Android device for flows that depend on native system UI:

- cold-launch startup splash
- Google native account chooser
- Android deep links
- USB-forwarded backend calls

Useful USB command:

```powershell
adb reverse tcp:5059 tcp:5059
```

Then run:

```powershell
cd mobile
flutter run -d <DEVICE_ID> --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059
```

## What To Test After Auth Changes

Run the full mobile suite, plus manual checks for:

1. Email/password registration.
2. Role selection after registration.
3. Google sign-in account chooser.
4. New Google user role onboarding.
5. Logout and sign-in persistence.
6. Password reset recovery route.

## What To Test After Family Changes

Run backend application/integration tests and mobile family tests. Manually verify:

1. Guardian creates a family circle.
2. Guardian creates an invite.
3. Member accepts invite by code/link.
4. Guardian changes member permissions.
5. Guardian removes member.
6. Removed member no longer has family access.
