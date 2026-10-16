import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shacheni_app/app/config.dart';
import 'package:shacheni_app/data/auth.dart';
import 'package:shacheni_app/data/system_web_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SupabaseClient client;
  late MemoryPkceStorage storage;
  late List<http.Request> requests;
  late List<MethodCall> calls;
  String? callbackResult;
  PlatformException? platformFailure;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    requests = [];
    calls = [];
    callbackResult = '$kMobileAuthRedirect?code=test-code';
    platformFailure = null;
    storage = MemoryPkceStorage();
    client = SupabaseClient(
      'https://example.invalid',
      'test-publishable-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: storage,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'user-1',
              'app_metadata': {},
              'user_metadata': {},
              'aud': 'authenticated',
              'created_at': '2026-10-14T10:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    messenger.setMockMethodCallHandler(SystemWebAuth.channel, (call) async {
      calls.add(call);
      if (platformFailure != null) throw platformFailure!;
      return callbackResult;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(SystemWebAuth.channel, null);
    debugDefaultTargetPlatformOverride = null;
    await client.dispose();
  });

  test(
    'iOS sheet uses the registered callback and exchanges PKCE once',
    () async {
      final signedIn = client.auth.onAuthStateChange.firstWhere(
        (state) => state.event == AuthChangeEvent.signedIn,
      );
      await AuthRepository(client: client).signInWithGoogle();
      expect(calls.single.method, 'authenticate');
      final args = calls.single.arguments as Map;
      final authorize = Uri.parse(args['url'] as String);
      expect(args['callbackScheme'], Uri.parse(kMobileAuthRedirect).scheme);
      expect(authorize.path, '/auth/v1/authorize');
      expect(authorize.queryParameters['provider'], 'google');
      expect(authorize.queryParameters['redirect_to'], kMobileAuthRedirect);
      expect(authorize.queryParameters['code_challenge_method'], 's256');
      expect(authorize.queryParameters['prompt'], 'select_account');
      expect(requests.single.url.path, '/auth/v1/token');
      expect(requests.single.url.queryParameters['grant_type'], 'pkce');
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['auth_code'], 'test-code');
      expect(body['code_verifier'], isNotEmpty);
      expect(storage.values, isEmpty);
      expect((await signedIn).session!.user.id, 'user-1');
      expect(client.auth.currentUser!.id, 'user-1');
    },
  );

  test(
    'closing the sheet cancels quietly and allows another sign-in',
    () async {
      final repository = AuthRepository(client: client);
      callbackResult = null;
      await repository.signInWithGoogle();
      expect(requests, isEmpty);
      expect(client.auth.currentSession, isNull);
      callbackResult = '$kMobileAuthRedirect?code=retry-code';
      await repository.signInWithGoogle();
      expect(calls, hasLength(2));
      expect(
        (jsonDecode(requests.single.body) as Map)['auth_code'],
        'retry-code',
      );
      expect(client.auth.currentSession, isNotNull);
    },
  );

  test('a native presentation failure does not create a session', () async {
    platformFailure = PlatformException(code: 'AUTH_NO_WINDOW');
    await expectLater(
      AuthRepository(client: client).signInWithGoogle(),
      throwsA(isA<PlatformException>()),
    );
    expect(requests, isEmpty);
    expect(client.auth.currentSession, isNull);
  });

  test(
    'a callback for a different destination cannot exchange a code',
    () async {
      callbackResult = 'com.shacheni.shacheniapp://another-host?code=test-code';
      await expectLater(
        AuthRepository(client: client).signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );
      expect(requests, isEmpty);
      expect(client.auth.currentSession, isNull);
    },
  );

  test('provider refusal returns an error without exchanging a code', () async {
    callbackResult =
        '$kMobileAuthRedirect?error=access_denied&error_description=Denied';
    await expectLater(
      AuthRepository(client: client).signInWithGoogle(),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
    expect(client.auth.currentSession, isNull);
  });
}
