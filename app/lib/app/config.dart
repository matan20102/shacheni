/// Environment values, injected at build time (never hard-coded):
///   flutter run -d chrome --dart-define-from-file=config/dev.json
/// Without a config file the app runs on the in-memory demo data only.
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

bool get kBackendConfigured => kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;

/// Recorded with legal acceptances (keep in step with pubspec `version`).
const kAppVersion = '0.1.0';
