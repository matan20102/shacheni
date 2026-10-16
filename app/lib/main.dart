import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kBackendConfigured) {
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
  }
  runApp(const NayborApp());
}
