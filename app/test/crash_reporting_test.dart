import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shacheni_app/app/crash_reporting.dart';

void main() {
  test('crash reporting stays off without a DSN', () async {
    expect(crashReportingEnabled, isFalse);
    expect(await sendCrashReportingTest(), isFalse);
  });

  test('events lose user and request details before sending', () {
    final event = SentryEvent(
      user: SentryUser(id: 'u1', email: 'a@b.c', ipAddress: '1.2.3.4'),
      request: SentryRequest(url: 'https://x.test/?join=ABCD'),
    );
    final scrubbed = scrubEvent(event, Hint())!;
    expect(scrubbed.user, isNull);
    expect(scrubbed.request, isNull);
  });

  test('breadcrumb addresses lose their query strings', () {
    final crumb = Breadcrumb.http(
      url: Uri.parse('https://x.supabase.co/rest/v1/t?id=eq.42#frag'),
      method: 'GET',
    );
    final url = scrubBreadcrumb(crumb, Hint())!.data!['url'] as String;
    expect(url, isNot(contains('42')));
    expect(url, isNot(contains('frag')));
  });
}
