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

/// Public web address used in invitations (override per environment).
const kPublicAppUrl = String.fromEnvironment(
  'PUBLIC_APP_URL',
  defaultValue: 'https://shacheni-dev.netlify.app',
);

String inviteLink(String code) => '$kPublicAppUrl/?join=$code';

/// The join code carried by an invitation link, if this address is one.
/// A query parameter, not a route: the app has a single entry point.
String? joinCodeFromLink(Uri uri) {
  final code = uri.queryParameters['join']?.trim() ?? '';
  return RegExp(r'^[A-Za-z0-9]{4,12}$').hasMatch(code)
      ? code.toUpperCase()
      : null;
}
