# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Google Sign-In

"Continue with Google" (Welcome + Login screens) uses Supabase's own native OAuth
flow (`signInWithOAuth(OAuthProvider.google)`) — an external browser/Custom Tab +
PKCE + deep-link redirect back into the app, not the `google_sign_in` native
package.

- **Nothing to configure per-developer.** The Google provider is already
  configured on the Supabase dashboard side (Authentication -> Providers ->
  Google). Beyond the app's existing `SUPABASE_URL`/`SUPABASE_ANON_KEY`
  `--dart-define`s (see earlier Phase 1 setup notes), there is no additional
  client-side Google/OAuth configuration.
- **Redirect URL is reused, not new.** The OAuth `redirectTo` reuses the existing
  `safepathai://reset-password` constant (`lib/core/config/supabase_config.dart`)
  instead of registering a second URL in Supabase's dashboard — Supabase matches
  the redirect URL string itself, not the flow it's used for, and this URL is
  already allow-listed for password reset. This keeps the change to zero
  Supabase dashboard edits.
- **Platform deep-link registration.** Both `android/app/src/main/AndroidManifest.xml`
  (a `safepathai://` browsable `intent-filter` on `MainActivity`) and
  `ios/Runner/Info.plist` (a matching `CFBundleURLTypes` entry) now register the
  `safepathai://` scheme — previously missing on both platforms, which meant even
  the password-reset email link could not open the app. This registration serves
  both flows.
- **Testing.** Google Sign-In is unit/widget-tested with a mocked `AuthApi` /
  `AuthController` — it never drives a real Google OAuth flow in CI or automated
  tests. Manual verification requires a real device or emulator with Google Play
  Services and a real Google account.
