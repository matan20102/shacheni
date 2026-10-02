import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo_data.dart';
import 'models.dart';

/// Build-time switches for reviewing screens directly (dev only):
///   flutter run -d chrome --dart-define=DEMO_SIGNED_IN=true --dart-define=DEMO_LOCALE=en
const kDemoSignedIn = bool.fromEnvironment('DEMO_SIGNED_IN');
const kDemoLocale = String.fromEnvironment('DEMO_LOCALE');

class DemoState {
  const DemoState(this.data, this.rev);
  final DemoData data;
  final int rev;
}

/// Holds the mutable prototype store and re-emits a new state after every action so that
/// watching widgets rebuild.
class DemoNotifier extends Notifier<DemoState> {
  @override
  DemoState build() =>
      DemoState(DemoData(startStage: kDemoSignedIn ? AuthStage.approved : null), 0);

  void act(void Function(DemoData d) f) {
    f(state.data);
    state = DemoState(state.data, state.rev + 1);
  }

  void reset() {
    state = DemoState(DemoData(startStage: AuthStage.approved), state.rev + 1);
  }
}

final demoProvider = NotifierProvider<DemoNotifier, DemoState>(DemoNotifier.new);

/// Language resolution (PRD §5.4): saved choice → device language (he→he, en→en) → Hebrew.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    if (kDemoLocale == 'en') return const Locale('en');
    if (kDemoLocale == 'he') return const Locale('he');
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return device == 'en' ? const Locale('en') : const Locale('he');
  }

  void set(Locale l) => state = l;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

/// Shows the dashed "Demo: …" buttons that simulate the other party's actions.
class DemoToolsNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool v) => state = v;
}

final demoToolsProvider = NotifierProvider<DemoToolsNotifier, bool>(DemoToolsNotifier.new);
