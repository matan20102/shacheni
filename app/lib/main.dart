import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/appearance.dart';
import 'app/config.dart';
import 'app/crash_reporting.dart';

Future<void> main() => runWithCrashReporting(() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kBackendConfigured) {
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  }
  await appearance.load();
  runApp(const NayborApp());
});
