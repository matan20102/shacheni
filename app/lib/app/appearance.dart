import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The resident's light/dark choice. Follows the device until they pick one,
/// and is remembered on this device only.
class Appearance extends ValueNotifier<ThemeMode> {
  Appearance([super.value = ThemeMode.system]);

  static const _key = 'appearance.theme_mode';

  /// Reads the saved choice. Failures keep the system default.
  Future<void> load() async {
    try {
      final saved = await SharedPreferencesAsync().getString(_key);
      value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {}
  }

  Future<void> choose(ThemeMode mode) async {
    value = mode;
    try {
      await SharedPreferencesAsync().setString(_key, mode.name);
    } catch (_) {}
  }
}

final appearance = Appearance();
