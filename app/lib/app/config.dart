/// Environment values, injected at build time (never hard-coded):
///   flutter run -d chrome --dart-define-from-file=config/building-dev.json
/// Without a config file the app runs on the in-memory demo data only.
const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const kSupabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const kMobileAuthRedirect = 'com.shacheni.shacheniapp://login-callback';

bool get kBackendConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;

/// Marketing version recorded with legal acceptances (pubspec build name).
const kAppVersion = '0.1.0';
