import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('he');
  await initializeDateFormatting('en');
  if (kBackendConfigured) {
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  }
  runApp(const ProviderScope(child: ShacheniApp()));
}
