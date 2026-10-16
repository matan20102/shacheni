import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shacheni_app/data/building/board_read_store.dart';
import 'package:shacheni_app/features/building/building_connected_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String sessionJson() {
  final expires = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': expires, 'sub': 'reader'})))
      .replaceAll('=', '');
  return jsonEncode({
    'access_token': 'e30.$payload.signature',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': 'reader',
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-10-16T10:00:00Z',
    },
  });
}

Future<void> finishLoading(WidgetTester tester) async {
  // The real Supabase parser uses an isolate, outside the widget fake clock.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Startup did not finish');
}

void main() {
  late SupabaseClient client;
  late List<String> calls;
  late Completer<void> legalResponse;
  var needsConsent = false;
  var failLegal = false;

  setUp(() {
    calls = [];
    legalResponse = Completer<void>();
    needsConsent = false;
    failLegal = false;
    client = SupabaseClient(
      'https://example.invalid',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final action = request.url.path.split('/').last;
        calls.add(action);
        Object result;
        if (action == 'my_pending_legal_documents') {
          await legalResponse.future;
          if (failLegal) {
            return http.Response(
              '{"message":"unavailable","code":"TEST_ERROR"}',
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          result = needsConsent
              ? [
                  {
                    'type': 'terms_of_service',
                    'version': '1',
                    'title': 'תנאי שימוש',
                    'body_md': 'מסמך בדיקה',
                  },
                ]
              : [];
        } else if (action == 'ba_state') {
          result = {
            'homes': [
              {
                'id': 'building',
                'name': 'הבית המחובר',
                'address': 'הגננת 216, ירושלים',
                'apartment': '30',
              },
            ],
            'applications': [],
          };
        } else {
          result = [];
        }
        return http.Response(
          jsonEncode(result),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });
  tearDown(() => client.dispose());

  testWidgets('startup session events share one initial loading chain', (
    tester,
  ) async {
    await client.auth.setInitialSession(sessionJson());
    await tester.pumpWidget(
      BuildingConnectedApp(client: client, readStore: MemoryBoardReadStore()),
    );
    await tester.pump();
    // Supabase can deliver its initial session after the widget subscribes.
    await client.auth.setInitialSession(sessionJson());
    await tester.pump();
    legalResponse.complete();
    await finishLoading(tester);
    expect(calls, ['my_pending_legal_documents', 'ba_state', 'ba_board']);
    expect(find.text('הבית המחובר'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pending consent does not request building data', (tester) async {
    needsConsent = true;
    await client.auth.setInitialSession(sessionJson());
    legalResponse.complete();
    await tester.pumpWidget(
      BuildingConnectedApp(client: client, readStore: MemoryBoardReadStore()),
    );
    await finishLoading(tester);
    expect(calls, ['my_pending_legal_documents']);
    expect(find.byKey(const Key('legal-consent-continue')), findsOneWidget);
    expect(find.text('הבית המחובר'), findsNothing);
  });

  testWidgets('sign out during startup never reveals the previous account', (
    tester,
  ) async {
    await client.auth.setInitialSession(sessionJson());
    await tester.pumpWidget(
      BuildingConnectedApp(client: client, readStore: MemoryBoardReadStore()),
    );
    await tester.pump();
    await client.auth.signOut(scope: SignOutScope.local);
    await tester.pump();
    legalResponse.complete();
    await finishLoading(tester);
    expect(calls, isNot(contains('ba_state')));
    expect(find.text('הבית המחובר'), findsNothing);
    expect(find.text('בית אחד.\nהרבה שכנים טובים.'), findsOneWidget);
  });

  testWidgets('failed startup offers retry and loads after recovery', (
    tester,
  ) async {
    failLegal = true;
    await client.auth.setInitialSession(sessionJson());
    legalResponse.complete();
    await tester.pumpWidget(
      BuildingConnectedApp(client: client, readStore: MemoryBoardReadStore()),
    );
    await finishLoading(tester);
    expect(find.text('ניסיון נוסף'), findsOneWidget);
    expect(calls, ['my_pending_legal_documents']);
    failLegal = false;
    await tester.tap(find.text('ניסיון נוסף'));
    await finishLoading(tester);
    expect(find.text('הבית המחובר'), findsWidgets);
    expect(calls.where((c) => c == 'ba_state'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
}
