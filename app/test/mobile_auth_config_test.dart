import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/app/config.dart';

void main() {
  test(
    'mobile OAuth callback matches iOS URL registration and plugin routing',
    () {
      final callback = Uri.parse(kMobileAuthRedirect);
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(callback.host, 'login-callback');
      expect(plist, contains('<string>${callback.scheme}</string>'));
      // The native OAuth session and Supabase's app_links listener handle auth;
      // Navigator must not also open an unknown login-callback route.
      expect(
        RegExp(r'<key>FlutterDeepLinkingEnabled</key>\s*<false\s*/>')
            .hasMatch(plist),
        isTrue,
      );
    },
  );
}
