const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const supabaseRedirectUrl = String.fromEnvironment(
  'SUPABASE_REDIRECT_URL',
  defaultValue: 'safepathai://reset-password',
);

/// The **Web** OAuth client's `client_id` (not the Android client's ID),
/// used by `google_sign_in`'s `serverClientId` so Google issues an ID token
/// whose audience Supabase's backend can verify against the Google provider
/// already configured on the dashboard (01-09-PLAN.md D-09-3). Public,
/// safe to embed in client code same as [supabaseAnonKey].
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

void ensureSupabaseConfigured() {
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Pass both via --dart-define.',
    );
  }
}
