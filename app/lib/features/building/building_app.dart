import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/building/building_repository.dart';
import '../../app/appearance.dart';
import '../../app/brand.dart';
import '../../app/config.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';
import 'invite_qr.dart';
import 'address_picker.dart';
import 'board_search.dart';
import 'board_timeline.dart';
import 'account_widgets.dart';
import 'resident_directory.dart';
import 'platform_console.dart';
import 'parking_screen.dart';

part 'building_home_tab.dart';
part 'building_board_tab.dart';
part 'building_menus.dart';
part 'building_join.dart';

String _apartmentLabel(BuildingHome home) => 'דירה ${home.apartment}';

class BuildingPreviewApp extends StatelessWidget {
  const BuildingPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: appearance,
    builder: (context, mode, _) => MaterialApp(
      title: '$appNameHebrew · $appNameEnglish',
      debugShowCheckedModeBanner: false,
      theme: buildingTheme(),
      darkTheme: buildingTheme(Brightness.dark),
      themeMode: mode,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const BuildingExperience(),
    ),
  );
}

@Preview(name: '$appNameHebrew · ניהול בניין', size: Size(390, 844))
Widget buildingExperiencePreview() => const BuildingPreviewApp();

class BuildingExperience extends StatefulWidget {
  const BuildingExperience({
    super.key,
    this.viewModel,
    this.onSignOut,
    this.initialJoinCode,
    this.onJoinCodeUsed,
  });
  final BuildingViewModel? viewModel;
  final Future<void> Function()? onSignOut;

  /// Code from an invitation link; opens the join form once.
  final String? initialJoinCode;
  final VoidCallback? onJoinCodeUsed;
  @override
  State<BuildingExperience> createState() => _BuildingExperienceState();
}

class _BuildingExperienceState extends State<BuildingExperience>
    with WidgetsBindingObserver {
  late final BuildingViewModel vm =
      widget.viewModel ?? BuildingViewModel(LocalBuildingRepository());
  final timelineKey = GlobalKey<BoardTimelineState>();
  Timer? syncTimer;
  int syncTicks = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSync();
    final invited = widget.initialJoinCode;
    if (invited != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onJoinCodeUsed?.call();
        if (!vm.homes.any((h) => h.code == invited)) _join(code: invited);
      });
    }
  }

  void _startSync() {
    syncTimer?.cancel();
    syncTicks = 0;
    if (vm.live) {
      syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        syncTicks++;
        if (vm.needsFastSync || syncTicks % 4 == 0) {
          _sync();
        }
      });
    }
  }

  Future<void> _sync() async {
    try {
      await vm.synchronize();
    } catch (_) {
      /* Retry on resume/next interval. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    syncTimer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _sync();
      _startSync();
    }
  }

  /// The floating tab bar narrows while the resident scrolls down.
  final navCompact = ValueNotifier(false);
  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final down = switch (n.direction) {
      ScrollDirection.reverse => true,
      ScrollDirection.forward => false,
      ScrollDirection.idle => navCompact.value,
    };
    // The board is reversed (newest at the bottom): flip the sense there.
    final reversed = n.metrics.axisDirection == AxisDirection.up;
    navCompact.value = reversed ? !down : down;
    return false;
  }

  void _navigate(int value) {
    if (value != vm.tab) HapticFeedback.selectionClick();
    navCompact.value = false;
    vm.navigate(value);
    if (vm.live) _sync();
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    navCompact.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.viewModel == null) vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) =>
        GlassBackground(child: vm.entered ? _shell() : _welcome()),
  );

  Widget _welcome() => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Eyebrow(appNameHebrew),
                  SoftTag('תצוגת פיתוח מקומית', icon: Icons.science_outlined),
                ],
              ),
              const SizedBox(height: 64),
              const Center(child: BuildingMark(size: 130)),
              const SizedBox(height: Space.xxxl),
              Text(
                'בית אחד.\nהרבה שכנים טובים.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: Space.l),
              Text(
                'כל מה שקורה בבניין, במקום אחד פשוט.\nלהתעדכן, לעזור ולנהל את הבית יחד.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.7,
                  color: context.glass.muted,
                ),
              ),
              const SizedBox(height: Space.xxxl),
              const GlassPanel(
                child: Column(
                  children: [
                    _FeatureLine(
                      Icons.forum_outlined,
                      'לוח אחד לכל הבניין',
                      'עדכונים קטנים, עזרה גדולה',
                    ),
                    SizedBox(height: Space.xl),
                    _FeatureLine(
                      Icons.home_outlined,
                      'הבית שלך במרכז',
                      'מידע ופניות הנוגעים לדירה שלך',
                    ),
                    SizedBox(height: Space.xl),
                    _FeatureLine(
                      Icons.people_outline,
                      'מנהלים יחד',
                      'הצטרפות באישור מנהלי הבניין והדירה',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              FilledButton.icon(
                onPressed: vm.enter,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('כניסה לבניין לדוגמה'),
              ),
              const SizedBox(height: Space.m),
              Text(
                'נתוני הדגמה בלבד · השינויים נשמרים עד סגירת האפליקציה.\nכניסה עם Google זמינה כרגע בגרסה המחוברת הקיימת.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: context.glass.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _shell() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final content = Column(
        children: [
          _header(),
          if (vm.busy) const LinearProgressIndicator(minHeight: 2),
          if (vm.repository.boardError != null)
            MaterialBanner(
              content: const Text(
                'הבניין מעודכן, אבל לא הצלחנו לטעון את הלוח.',
              ),
              actions: [
                TextButton(
                  onPressed: vm.busy
                      ? null
                      : () => _perform(() {}, refresh: true),
                  child: const Text('ניסיון נוסף'),
                ),
              ],
            ),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onScroll,
              child: TopFade(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: EnterTransition(
                      key: ValueKey('tab-${vm.tab}'),
                      child: switch (vm.tab) {
                        0 => _home(),
                        1 => _board(),
                        2 =>
                          vm.active == null
                              ? _later(
                                  'חניה',
                                  'מקום קטן. עזרה גדולה.',
                                  Icons.local_parking_rounded,
                                  'מצטרפים לבניין כדי לשתף ולהזמין חניות עם השכנים.',
                                )
                              : ParkingScreen(
                                  key: ValueKey('parking-${vm.active!.id}'),
                                  repository: vm.repository.parking,
                                  buildingId: vm.active!.id,
                                  apartment: vm.active!.apartment,
                                ),
                        _ => _later(
                          'ועד בית',
                          'הבית שלנו, בניהול משותף.',
                          Icons.account_balance_wallet_outlined,
                          'כאן יופיעו קופת הבניין, ההוצאות והחיובים של הדירה שלך.\nמסלול הגבייה יתווסף בשלב הבא.',
                        ),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (wide)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 8,
                    ),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: vm.tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: _navigate,
                      leading: const Padding(
                        padding: EdgeInsets.only(bottom: 28),
                        child: BuildingMark(size: 56),
                      ),
                      destinations: [
                        for (final item in _navItems)
                          NavigationRailDestination(
                            icon: Icon(item.$2),
                            label: Text(item.$1),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : SafeArea(
                top: false,
                child: ValueListenableBuilder(
                  valueListenable: navCompact,
                  builder: (context, compact, _) => FloatingNav(
                    items: _navItems,
                    selected: vm.tab,
                    onSelect: _navigate,
                    compact: compact,
                  ),
                ),
              ),
      );
    },
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                key: const Key('building-selector'),
                button: true,
                label: 'בחירת בניין',
                child: InkWell(
                  onTap: _chooseBuilding,
                  borderRadius: BorderRadius.circular(22),
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    radius: 22,
                    child: Row(
                      children: [
                        Icon(
                          Icons.apartment_rounded,
                          color: context.glass.accent,
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vm.active?.name ?? 'הבניינים שלי',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                vm.active == null
                                    ? 'יצירה או הצטרפות לבניין'
                                    : [
                                        if (vm.active!.name !=
                                            vm.active!.address)
                                          vm.active!.address,
                                        _apartmentLabel(vm.active!),
                                        if (vm.active!.householdName.isNotEmpty)
                                          vm.active!.householdName,
                                      ].join(' · '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.glass.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 19,
                          color: context.glass.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Tooltip(
              message: 'עדכונים ובקשות',
              child: IconButton.filledTonal(
                key: const Key('building-updates'),
                onPressed: _applications,
                style: IconButton.styleFrom(
                  backgroundColor: context.glass.glassStrong,
                ),
                icon: Badge(
                  key: const Key('building-updates-badge'),
                  isLabelVisible: vm.notificationCount > 0,
                  label: Text(
                    vm.notificationCount > 99
                        ? '99+'
                        : '${vm.notificationCount}',
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: context.glass.ink,
                  ),
                ),
              ),
            ),
            AccountMenu(
              profile: vm.repository.profile,
              onPlatform: vm.repository.isPlatformAdmin
                  ? _platformConsole
                  : null,
              onProfile: _profile,
              onSignOut: widget.onSignOut == null
                  ? null
                  : () => _perform(widget.onSignOut!, refresh: false),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _later(
    String eyebrow,
    String title,
    IconData icon,
    String description,
  ) => ListView(
    padding: const EdgeInsets.all(Space.xl),
    children: [
      Eyebrow(eyebrow),
      const SizedBox(height: Space.s),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: Space.xxl),
      StateMessage(
        icon: icon,
        title: 'בקרוב',
        text: description,
        action: const SoftTag('בשלב הבא', icon: Icons.schedule_rounded),
      ),
    ],
  );

  Widget _empty(String title, String text, VoidCallback action) => StateMessage(
    icon: Icons.forum_outlined,
    title: title,
    text: text,
    action: FilledButton(onPressed: action, child: const Text('מתחילים כאן')),
  );

  Future<void> _sheet(Widget Function(BuildContext) builder) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: builder(ctx),
        ),
      );

  Future<bool> _perform(
    FutureOr<void> Function() action, {
    bool refresh = true,
  }) async {
    try {
      if (refresh) {
        await vm.run(action);
      } else {
        await action();
      }
      return true;
    } catch (error) {
      if (mounted) _message(buildingErrorMessage(error));
      return false;
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

const _navItems = [
  ('הבית שלי', Icons.home_outlined),
  ('לוח הבניין', Icons.forum_outlined),
  ('חניה', Icons.local_parking_rounded),
  ('ועד בית', Icons.account_balance_wallet_outlined),
];
String _relative(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.inMinutes < 1) return 'עכשיו';
  if (elapsed.inMinutes < 60) {
    return _ago(elapsed.inMinutes, 'דקה', 'שתי דקות', 'דקות');
  }
  if (elapsed.inHours < 24) {
    return _ago(elapsed.inHours, 'שעה', 'שעתיים', 'שעות');
  }
  if (elapsed.inDays < 7) return _ago(elapsed.inDays, 'יום', 'יומיים', 'ימים');
  return '\u2066${time.day}.${time.month}.${time.year % 100}\u2069';
}

String _ago(int n, String one, String two, String many) => switch (n) {
  1 => 'לפני $one',
  2 => 'לפני $two',
  _ => 'לפני $n $many',
};

String _replyCount(int count) => count == 1 ? 'תגובה אחת' : '$count תגובות';

Widget _field(
  TextEditingController controller,
  String label,
  String hint, {
  bool required = true,
  int maxLength = 120,
  Key? key,
}) => TextFormField(
  key: key,
  controller: controller,
  maxLength: maxLength,
  decoration: InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: '',
  ),
  validator: (v) =>
      required && (v?.trim().isEmpty ?? true) ? 'יש למלא את השדה' : null,
);

Widget _apartmentField(
  TextEditingController controller, {
  Key? key,
  ValueChanged<String>? onChanged,
}) => TextFormField(
  key: key,
  controller: controller,
  keyboardType: TextInputType.number,
  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  maxLength: 20,
  onChanged: onChanged,
  decoration: const InputDecoration(
    labelText: 'מספר הדירה',
    hintText: 'למשל: 12',
    counterText: '',
  ),
  validator: (value) =>
      value == null || !RegExp(r'^[0-9]+$').hasMatch(value.trim())
      ? 'יש להזין מספר דירה בספרות בלבד'
      : null,
);

mixin _AsyncForm<T extends StatefulWidget> on State<T> {
  bool submitting = false;
  String? submitError;
  Future<void> submit(Future<void> Function() action) async {
    if (submitting) return;
    setState(() {
      submitting = true;
      submitError = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => submitError = buildingErrorMessage(error));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
