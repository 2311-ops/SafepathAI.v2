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

"Continue with Google" (Welcome + Login screens) uses the `google_sign_in`
package's **native** on-device account picker
(`GoogleSignIn.instance.authenticate()`) plus Supabase's
`signInWithIdToken(provider: OAuthProvider.google, idToken: ...)` — not the
browser/Custom Tab `signInWithOAuth` flow. This is a deliberate 01-09 reversal
of 01-08's original browser-based implementation, made so no Supabase/Google
URL is ever shown to the user during sign-in.

- **Required client-side config: `GOOGLE_SERVER_CLIENT_ID`.** Add this key to
  `mobile/env.json` (gitignored) and pass it via `--dart-define-from-file`,
  same pattern as `SUPABASE_URL`/`SUPABASE_ANON_KEY`. Its value is the
  **Web** OAuth client's `client_id` (the one already configured as
  Supabase's Google provider on the dashboard) — **not** the Android
  client's ID. It's a public identifier, safe to commit to client code (like
  the Supabase anon key), but is read from `env.json` here to match the
  project's existing config pattern. `signInWithGoogle()` throws a
  `StateError` loudly if this is missing, rather than failing silently.
- **Required Google Cloud Console prerequisite: an Android OAuth client.**
  Google's native sign-in flow validates the calling app against an
  **Android**-type OAuth client registered in Google Cloud Console with this
  app's package name (`com.safepath.mobile`) and the signing certificate's
  SHA-1 fingerprint. Every developer machine's debug keystore has a
  different SHA-1, so each developer needs their own debug SHA-1 registered
  (or a shared debug keystore checked into the team's secrets). Get your
  debug SHA-1 with:
  ```
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```
  A release build's SHA-1 (from the release signing key) must be registered
  separately before Google Sign-In will work in a release build — this is
  not automatic. If sign-in fails with a `PlatformException`/
  `ApiException: 10` (`DEVELOPER_ERROR`), a missing/mismatched SHA-1
  registration is the most likely cause.
- **Redirect URL / deep-link registration is unrelated to this flow now.**
  The `safepathai://` scheme registered on Android
  (`android/app/src/main/AndroidManifest.xml`) and iOS
  (`ios/Runner/Info.plist`) is still required for the password-reset deep
  link, but Google Sign-In itself no longer opens a browser or needs a
  redirect URL — the native picker returns directly to the app.
- **Cancellation has no lifecycle-recovery hack.** Unlike the superseded
  browser flow (which could leave the UI stuck in a loading state if a user
  backed out of the browser and returned to the app), `google_sign_in`'s
  `authenticate()` call is synchronously awaitable end-to-end — cancellation
  (`GoogleSignInExceptionCode.canceled`) resolves the same `await` directly,
  with no separate app-resume recovery step needed.
- **Testing.** Google Sign-In is unit/widget-tested with a mocked `AuthApi` /
  `AuthController` — it never drives a real Google sign-in flow in CI or
  automated tests. Manual verification requires a real device or emulator
  with Google Play Services, a real Google account, and the Android OAuth
  client prerequisite above correctly registered.
