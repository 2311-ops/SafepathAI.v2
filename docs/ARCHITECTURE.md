# Architecture

SafePath AI is split into a Flutter mobile client and an ASP.NET Core backend.

## High-Level Flow

```text
Flutter app
  ├─ Supabase Auth session and Google native sign-in
  ├─ Dio API client with bearer token attachment
  └─ Feature controllers and screens

ASP.NET Core API
  ├─ Controllers for profile, families, and invites
  ├─ Application command/query handlers
  ├─ Domain entities and enums
  └─ EF Core infrastructure over Postgres/Supabase
```

Supabase owns authentication sessions. The backend validates Supabase-issued JWTs and uses its own database tables for application data such as users, families, memberships, and invitations.

## Mobile App

Main entry points:

- `mobile/lib/main.dart`
- `mobile/lib/app.dart`
- `mobile/lib/core/router/app_router.dart`

Important mobile layers:

- `core/config/` - Supabase compile-time config and client provider.
- `core/network/` - Dio client and auth interceptor.
- `core/router/` - GoRouter routes and auth/splash redirect logic.
- `core/theme/` - SafePath color, spacing, typography, and ThemeData.
- `features/auth/` - welcome, register, login, password reset, role selection, Google sign-in.
- `features/family/` - create circle, invite, accept invite, manage permissions.
- `features/profile/` - `/me` profile restore and role update.
- `features/splash/` - startup splash animation and completion provider.
- `shared_widgets/` - buttons, cards, text fields, logo, Google sign-in button.

State management uses Riverpod providers and controllers. Routing uses GoRouter. API calls use Dio with bearer tokens from the active Supabase session.

## Backend

The backend follows four projects:

- `SafePath.Api` - ASP.NET Core host, controllers, auth, CORS, rate limiting, OpenAPI in development.
- `SafePath.Application` - command/query handlers and application interfaces.
- `SafePath.Domain` - entities and enums.
- `SafePath.Infrastructure` - EF Core `ApplicationDbContext`, entity configurations, migrations, identity helpers, and DI.

Current controllers:

- `MeController` - profile restore and role onboarding.
- `FamiliesController` - create/list families, members, permissions, ownership, deletion.
- `InvitesController` - generate, revoke, and redeem invites.

## Auth Model

The app signs users in through Supabase:

- Email/password registration and login use `supabase_flutter`.
- Google sign-in uses `google_sign_in` to open the native account chooser, then sends Google tokens to Supabase.
- Password reset uses Supabase recovery links and the app's reset route.

The backend configures `JwtBearer` validation against the Supabase issuer in `SafePath.Api/Program.cs`.

## Data Model

Core domain entities live in `backend/src/SafePath.Domain/Entities`:

- `User`
- `Family`
- `FamilyMember`
- `FamilyInvitation`

Enums live in `backend/src/SafePath.Domain/Enums`:

- `Role`
- `PermissionLevel`
- `InvitationStatus`

EF Core configurations and migrations live under `backend/src/SafePath.Infrastructure/Persistence`.

## Startup Splash

The app starts at `/splash`. `SplashScreen` flips `splashAnimationCompleteProvider` after the animation completes, and the router redirects to the correct destination based on auth state:

- signed out -> welcome
- signed in -> home
- password recovery -> reset password
- signed in without role -> role onboarding

## Design System

The Flutter UI uses shared SafePath theme files in `mobile/lib/core/theme` and shared widgets in `mobile/lib/shared_widgets`. Phase 1 and 01.1 screens use this system for auth, family setup, and splash surfaces.
