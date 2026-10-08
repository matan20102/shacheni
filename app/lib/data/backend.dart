import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../app/config.dart';

enum BackendStatus { notConfigured, connected, unreachable }

/// Pings the Supabase Auth health endpoint (works before any table exists).
final backendStatusProvider = FutureProvider<BackendStatus>((ref) async {
  if (!kBackendConfigured) return BackendStatus.notConfigured;
  try {
    final res = await http
        .get(Uri.parse('$kSupabaseUrl/auth/v1/health'), headers: {'apikey': kSupabaseKey})
        .timeout(const Duration(seconds: 8));
    return res.statusCode == 200 ? BackendStatus.connected : BackendStatus.unreachable;
  } catch (_) {
    return BackendStatus.unreachable;
  }
});
