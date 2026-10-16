import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The iOS authentication sheet owns the callback and dismisses on completion.
/// A null result means the user closed the sheet without signing in.
class SystemWebAuth {
  const SystemWebAuth();

  static const channel = MethodChannel('com.shacheni/system_web_auth');

  Future<Uri?> authenticate(Uri url, {required Uri callback}) async {
    final result = await channel.invokeMethod<String>('authenticate', {
      'url': url.toString(),
      'callbackScheme': callback.scheme,
    });
    if (result == null) return null;
    final returned = Uri.parse(result);
    if (returned.scheme != callback.scheme ||
        returned.host != callback.host ||
        returned.path != callback.path ||
        returned.hasPort ||
        returned.userInfo.isNotEmpty) {
      throw const AuthException('כתובת החזרה מהכניסה אינה תקינה.');
    }
    return returned;
  }
}
