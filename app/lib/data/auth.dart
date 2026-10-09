import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config.dart';
import 'membership.dart';
import 'models.dart';
import 'providers.dart';

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
  const LegalDoc({required this.type, required this.version, required this.title, required this.body});

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
  SupabaseClient get _db => Supabase.instance.client;

  /// Google OAuth. On the web this navigates away to Google and comes back to this origin,
  /// where supabase_flutter picks the session up from the URL.
  Future<void> signInWithGoogle() async {
    await _db.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : null,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Current terms/privacy versions the user has not accepted yet (consent gate S04).
  Future<List<LegalDoc>> pendingLegal(String locale) async {
    final rows = await _db.rpc('my_pending_legal_documents', params: {'p_locale': locale}) as List;
    return [for (final r in rows) LegalDoc.fromRow(r as Map<String, dynamic>)];
  }

  Future<void> acceptLegal(List<String> routeTypes, String locale) async {
    await _db.rpc('accept_legal_documents', params: {
      'p_types': [for (final t in routeTypes) kLegalDbType[t]],
      'p_locale': locale,
      'p_app_version': kAppVersion,
    });
  }

  Future<LegalDoc?> currentDoc(String routeType, String locale) async {
    final rows = await _db.rpc('get_current_legal_documents', params: {
      'p_types': [kLegalDbType[routeType]],
      'p_locale': locale,
    }) as List;
    return rows.isEmpty ? null : LegalDoc.fromRow(rows.first as Map<String, dynamic>);
  }
}

final authRepoProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Where the real backend says the user is (from `get_my_access`). `demo` = no backend configured.
///   consent → terms/privacy not accepted · join → no live membership (none, withdrawn, rejected)
///   pending → applied / asked for info / disabled · ready → approved resident
enum Gate { demo, loading, signedOut, consent, join, pending, ready }

class GateNotifier extends Notifier<Gate> {
  @override
  Gate build() {
    if (!kBackendConfigured) return Gate.demo;
    final sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) => refresh());
    ref.onDispose(sub.cancel);
    Future.microtask(refresh);
    return Supabase.instance.client.auth.currentSession == null ? Gate.signedOut : Gate.loading;
  }

  Future<void> refresh() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      ref.read(myAccessProvider.notifier).set(null);
      ref.read(joinInfoProvider.notifier).set(null);
      state = Gate.signedOut;
      return;
    }
    try {
      final access = await ref.read(membershipRepoProvider).myAccess();
      ref.read(myAccessProvider.notifier).set(access);
      state = switch (access) {
        MyAccess(legalPending: true) => Gate.consent,
        MyAccess(membership: Membership(status: 'approved')) => Gate.ready,
        MyAccess(membership: Membership(status: 'pending' || 'info_requested' || 'disabled')) => Gate.pending,
        _ => Gate.join,
      };
    } catch (_) {
      state = Gate.consent; // fail closed: the consent screen shows the error and a retry
    }
  }
}

final gateProvider = NotifierProvider<GateNotifier, Gate>(GateNotifier.new);

/// Log out of the backend (if any) and send the prototype back to the welcome screen.
Future<void> signOutEverywhere(WidgetRef ref) async {
  if (ref.read(gateProvider) != Gate.demo) await ref.read(authRepoProvider).signOut();
  ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.welcome);
}
