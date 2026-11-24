import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config.dart';

/// Crash reporting (Sentry). Off unless the build is given a SENTRY_DSN, so local runs,
/// tests and the demo never send anything.
///
/// Privacy: only the error, its stack trace and technical context (browser, app version)
/// are sent. No names, emails, phone numbers, IP addresses, screenshots or request bodies.
const kSentryDsn = String.fromEnvironment('SENTRY_DSN');
const kSentryEnvironment = String.fromEnvironment(
  'SENTRY_ENVIRONMENT',
  defaultValue: 'production',
);

bool get crashReportingEnabled => kSentryDsn.isNotEmpty;

/// Starts [appRunner], wrapped by Sentry when it is configured.
Future<void> runWithCrashReporting(Future<void> Function() appRunner) async {
  if (!crashReportingEnabled) return appRunner();
  await SentryFlutter.init((options) {
    options
      ..dsn = kSentryDsn
      ..environment = kSentryEnvironment
      ..release = 'naybor@$kAppVersion'
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..tracesSampleRate = 0
      ..beforeSend = scrubEvent
      ..beforeBreadcrumb = scrubBreadcrumb;
  }, appRunner: appRunner);
}

/// Drops anything that could identify a resident before an event leaves the device.
@visibleForTesting
SentryEvent? scrubEvent(SentryEvent event, Hint hint) {
  event.user = null;
  event.request = null;
  return event;
}

/// Keeps breadcrumbs (the steps before a crash) but strips addresses' query strings,
/// which can carry ids or join codes.
@visibleForTesting
Breadcrumb? scrubBreadcrumb(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;
  final data = crumb.data;
  if (data != null && data['url'] is String) {
    final url = Uri.tryParse(data['url'] as String);
    if (url != null) {
      data['url'] = url.replace(query: '', fragment: '').toString();
    }
  }
  return crumb;
}

/// Sends a harmless test report, so an admin can confirm that reports arrive.
Future<bool> sendCrashReportingTest() async {
  if (!crashReportingEnabled) return false;
  final id = await Sentry.captureException(
    StateError('בדיקת ניטור קריסות מתוך ניהול המערכת (אפשר להתעלם)'),
    stackTrace: StackTrace.current,
  );
  return id != SentryId.empty();
}
