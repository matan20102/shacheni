import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config.dart';
import 'system_web_auth.dart';

/// Short route ids used by the screens (`/doc/terms`) ↔ `legal_doc_type` values in the database.
const kLegalDbType = {
  'terms': 'terms_of_service',
  'privacy': 'privacy_policy',
  'rules': 'community_rules',
  'declaration': 'resident_declaration',
  'agreement': 'building_agreement',
};
final kLegalRouteType = {for (final e in kLegalDbType.entries) e.value: e.key};

/// A row of `legal_document` (only the fields the app shows).
class LegalDoc {
  const LegalDoc({
    required this.type,
    required this.version,
    required this.title,
    required this.body,
  });

  factory LegalDoc.fromRow(Map<String, dynamic> r) => LegalDoc(
    type: kLegalRouteType[r['type']] ?? r['type'] as String,
    version: r['version'] as String,
    title: r['title'] as String,
    body: r['body_md'] as String,
  );

  final String type; // short route id ('terms', 'privacy', …)
  final String version;
  final String title;
  final String body;
}

/// Sign-in and the consent gate against Supabase. Only used when [kBackendConfigured].
class AuthRepository {
  AuthRepository({this.client, SystemWebAuth? systemWebAuth})
    : _systemWebAuth = systemWebAuth ?? const SystemWebAuth();

  final SupabaseClient? client;
  final SystemWebAuth _systemWebAuth;
  SupabaseClient get _db => client ?? Supabase.instance.client;

  /// Google OAuth. On the web this navigates away to Google and comes back to this origin,
  /// where supabase_flutter picks the session up from the URL.
  Future<void> signInWithGoogle() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final callback = Uri.parse(kMobileAuthRedirect);
      final response = await _db.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: callback.toString(),
        queryParams: const {'prompt': 'select_account'},
      );
      final returned = await _systemWebAuth.authenticate(
        Uri.parse(response.url),
        callback: callback,
      );
      if (returned != null) await _db.auth.getSessionFromUrl(returned);
      return;
    }
    await _db.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : kMobileAuthRedirect,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Current terms/privacy versions the user has not accepted yet (consent gate S04).
  Future<List<LegalDoc>> pendingLegal(String locale) async {
    final rows = await _db.rpc(
      'my_pending_legal_documents',
      params: {'p_locale': locale},
    ) as List;
    return [for (final r in rows) LegalDoc.fromRow(r as Map<String, dynamic>)];
  }

  Future<void> acceptLegal(List<String> routeTypes, String locale) async {
    await _db.rpc(
      'accept_legal_documents',
      params: {
        'p_types': [for (final t in routeTypes) kLegalDbType[t]],
        'p_locale': locale,
        'p_app_version': kAppVersion,
      },
    );
  }
}
