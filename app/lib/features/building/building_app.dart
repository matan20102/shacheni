import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/building/building_repository.dart';
import '../../app/brand.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';
import 'address_picker.dart';
import 'board_timeline.dart';

String _apartmentLabel(BuildingHome home) => 'דירה ${home.apartment}';

class BuildingPreviewApp extends StatelessWidget {
  const BuildingPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '$appNameHebrew · $appNameEnglish',
    debugShowCheckedModeBanner: false,
    theme: buildingTheme(),
    locale: const Locale('he'),
    supportedLocales: const [Locale('he')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const BuildingExperience(),
  );
}

@Preview(name: '$appNameHebrew · ניהול בניין', size: Size(390, 844))
Widget buildingExperiencePreview() => const BuildingPreviewApp();

class BuildingExperience extends StatefulWidget {
  const BuildingExperience({super.key, this.viewModel, this.onSignOut});
  final BuildingViewModel? viewModel;
  final Future<void> Function()? onSignOut;
  @override
  State<BuildingExperience> createState() => _BuildingExperienceState();
}

class _BuildingExperienceState extends State<BuildingExperience>
    with WidgetsBindingObserver {
  late final BuildingViewModel vm =
      widget.viewModel ?? BuildingViewModel(LocalBuildingRepository());
  final timelineKey = GlobalKey<BoardTimelineState>();
  Timer? syncTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSync();
  }

  void _startSync() {
    syncTimer?.cancel();
    if (vm.live) {
      syncTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sync());
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

  void _navigate(int value) {
    vm.navigate(value);
    if (vm.live) _sync();
  }

  @override
  void dispose() {
    syncTimer?.cancel();
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
              const SizedBox(height: 32),
              Text(
                'בית אחד.\nהרבה שכנים טובים.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'כל מה שקורה בבניין, במקום אחד פשוט.\nלהתעדכן, לעזור ולנהל את הבית יחד.',
                style: TextStyle(fontSize: 17, height: 1.7, color: glassMuted),
              ),
              const SizedBox(height: 32),
              const GlassPanel(
                child: Column(
                  children: [
                    _FeatureLine(
                      Icons.forum_outlined,
                      'לוח אחד לכל הבניין',
                      'עדכונים קטנים, עזרה גדולה',
                    ),
                    SizedBox(height: 18),
                    _FeatureLine(
                      Icons.home_outlined,
                      'הבית שלך במרכז',
                      'מידע ופניות הנוגעים לדירה שלך',
                    ),
                    SizedBox(height: 18),
                    _FeatureLine(
                      Icons.people_outline,
                      'מנהלים יחד',
                      'הצטרפות באישור מנהלי הבניין והדירה',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: vm.enter,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('כניסה לבניין לדוגמה'),
              ),
              const SizedBox(height: 12),
              const Text(
                'נתוני הדגמה בלבד · השינויים נשמרים עד סגירת האפליקציה.\nכניסה עם Google זמינה כרגע בגרסה המחוברת הקיימת.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.6, color: glassMuted),
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
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: switch (vm.tab) {
                  0 => _home(),
                  1 => _board(),
                  2 => _later(
                    'חניה',
                    'מקום קטן. עזרה גדולה.',
                    Icons.local_parking_rounded,
                    'כאן נוכל לשתף חניה פנויה ולהזמין אותה לכל הטווח.\nמסלול החניה יתווסף בשלב הבא.',
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: GlassPanel(
                    padding: EdgeInsets.zero,
                    radius: 28,
                    opacity: .78,
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      height: 74,
                      selectedIndex: vm.tab,
                      onDestinationSelected: _navigate,
                      indicatorColor: glassTeal.withValues(alpha: .13),
                      destinations: [
                        for (final item in _navItems)
                          NavigationDestination(
                            icon: Icon(item.$2),
                            label: item.$1,
                          ),
                      ],
                    ),
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
                        const Icon(Icons.apartment_rounded, color: glassTeal),
                        const SizedBox(width: 10),
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
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: glassMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.unfold_more_rounded,
                          size: 19,
                          color: glassMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: 'עדכונים ובקשות',
              child: IconButton.filledTonal(
                key: const Key('building-updates'),
                onPressed: _applications,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .75),
                ),
                icon: Badge(
                  key: const Key('building-updates-badge'),
                  isLabelVisible: vm.notificationCount > 0,
                  label: Text('${vm.notificationCount}'),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: glassInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _home() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
    children: [
      const Eyebrow('טוב להיות בבית'),
      const SizedBox(height: 6),
      Text('שלום, שכן 👋', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      const Text(
        'הדברים הקטנים שמחברים את הבניין.',
        style: TextStyle(color: glassMuted, fontSize: 15),
      ),
      const SizedBox(height: 24),
      GlassPanel(
        tint: const Color(0xFFBEE7E3),
        opacity: .55,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('הבית שלי'),
                  const SizedBox(height: 8),
                  Text(
                    vm.active == null
                        ? 'מתחילים עם הבניין שלך'
                        : vm.active!.householdName.isNotEmpty
                        ? vm.active!.householdName
                        : _apartmentLabel(vm.active!),
                    style: Theme.of(context).textTheme.headlineMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vm.active == null
                        ? 'אפשר ליצור בניין או להצטרף עם קוד.'
                        : vm.active!.householdName.isEmpty
                        ? vm.active!.name
                        : '${vm.active!.name} · ${_apartmentLabel(vm.active!)}',
                    style: const TextStyle(color: glassMuted),
                  ),
                  const SizedBox(height: 12),
                  SoftTag(
                    vm.live ? 'הבית שלך' : 'נתוני הדגמה',
                    icon: vm.live
                        ? Icons.check_circle_outline
                        : Icons.science_outlined,
                  ),
                  if (vm.active?.isApartmentAdmin ?? false)
                    TextButton.icon(
                      key: const Key('household-edit'),
                      onPressed: _editHousehold,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: Text(
                        vm.active!.householdName.isEmpty
                            ? 'לתת שם לבית'
                            : 'עריכת שם הבית',
                      ),
                    ),
                ],
              ),
            ),
            const BuildingMark(size: 78),
          ],
        ),
      ),
      const SectionTitle('מה עושים היום?'),
      LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: (c.maxWidth - 12) / 2,
              child: _ActionCard(
                Icons.edit_note_rounded,
                vm.active == null ? 'יצירת בניין' : 'לפרסם בלוח',
                vm.active == null ? 'מתחילים בית חדש' : 'עדכון או בקשת עזרה',
                () {
                  if (vm.active == null) {
                    _create();
                    return;
                  }
                  vm.navigate(1);
                  _compose();
                },
              ),
            ),
            SizedBox(
              width: (c.maxWidth - 12) / 2,
              child: _ActionCard(
                vm.active == null
                    ? Icons.add_home_outlined
                    : Icons.forum_outlined,
                vm.active == null ? 'הצטרפות לבניין' : 'לוח הבניין',
                vm.active == null ? 'עם הקוד שקיבלת' : 'מה חדש אצל השכנים',
                vm.active == null ? _join : () => _navigate(1),
              ),
            ),
          ],
        ),
      ),
      SectionTitle(
        'מה חדש בבניין',
        action: TextButton(
          onPressed: () => vm.navigate(1),
          child: const Text('לכל הפרסומים'),
        ),
      ),
      if (vm.posts.isEmpty)
        _empty(
          'הלוח שלכם מתחיל כאן',
          'עדכון ראשון הוא דרך טובה להגיד שלום.',
          _compose,
        )
      else
        for (final post in vm.posts.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _conversation(post.id),
              borderRadius: BorderRadius.circular(26),
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.author,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (post.pinned)
                          const SoftTag('נעוץ', icon: Icons.push_pin_outlined),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      post.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${post.replies.length} תגובות · לפתיחת השיחה',
                      style: const TextStyle(color: glassTeal, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      const SectionTitle('נעים להכיר'),
      const GlassPanel(
        child: _FeatureLine(
          Icons.waving_hand_outlined,
          'השכנים, קרוב מתמיד',
          'פניות פרטיות לדירה יתווספו בהמשך.\nהתוכן שלהן יהיה גלוי רק למשתתפים.',
        ),
      ),
    ],
  );

  Widget _board() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('השיחה של הבניין'),
                  const SizedBox(height: 4),
                  Text(
                    'לוח הבניין',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            IconButton.filled(
              key: const Key('board-new-post'),
              onPressed: vm.active == null ? null : _compose,
              tooltip: 'פרסום חדש',
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
      if (vm.posts.any((p) => p.pinned)) _pinnedBanner(),
      Expanded(
        child: vm.posts.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _empty(
                    'עוד אין כאן פרסומים',
                    'יש משהו לשתף עם השכנים?',
                    vm.active == null ? _chooseBuilding : _compose,
                  ),
                ],
              )
            : BoardTimeline(
                key: timelineKey,
                buildingId: vm.active!.id,
                posts: vm.posts.reversed.toList(),
                readStore: vm.readStore,
                itemBuilder: _postCard,
              ),
      ),
    ],
  );

  Widget _pinnedBanner() {
    final pinned = vm.posts.where((p) => p.pinned).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      child: InkWell(
        onTap: () => _conversation(pinned.first.id),
        borderRadius: BorderRadius.circular(12),
        child: GlassPanel(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 15, color: glassTeal),
              const SizedBox(width: 6),
              Text(
                pinned.length == 1 ? 'נעוץ' : '${pinned.length} נעוצים',
                style: const TextStyle(fontSize: 11, color: glassTeal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pinned.first.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postCard(BoardPost post) => Align(
    key: Key('board-post-${post.id}'),
    alignment: post.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: .96,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          tint: post.mine ? const Color(0xFFD8F0ED) : Colors.white,
          opacity: post.closed ? .65 : .88,
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: post.mine
                        ? glassTeal
                        : const Color(0xFFE0E8F0),
                    foregroundColor: post.mine ? Colors.white : glassInk,
                    child: Text(
                      post.author.characters.first,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'דירה ${post.apartment.split(' · כניסה ').first} · ${post.kind == PostKind.request ? 'בקשת עזרה' : 'מודעה'} · ${_relative(post.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: glassMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.pinned)
                    const Icon(
                      Icons.push_pin_outlined,
                      size: 14,
                      color: glassTeal,
                    ),
                  if (post.closed)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: glassTeal,
                      ),
                    ),
                  _postOptions(post),
                ],
              ),
              InkWell(
                onTap: () => _conversation(post.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    post.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
              if (post.closed)
                Text(
                  post.kind == PostKind.request ? 'נפתר' : 'לא רלוונטי',
                  style: const TextStyle(fontSize: 10, color: glassMuted),
                ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final reaction in post.reactions.entries)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: post.myReactions.contains(reaction.key)
                          ? const Color(0xFFB7DED7)
                          : Colors.white.withValues(alpha: .6),
                      side: BorderSide.none,
                      label: Text(
                        '${reaction.key} ${reaction.value}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: vm.busy
                          ? null
                          : () => _perform(
                              () => vm.repository.react(post.id, reaction.key),
                            ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'הוספת תגובה באימוג׳י',
                    icon: const Icon(
                      Icons.add_reaction_outlined,
                      size: 18,
                      color: glassMuted,
                    ),
                    constraints: const BoxConstraints(minWidth: 80),
                    padding: EdgeInsets.zero,
                    onSelected: (emoji) =>
                        _perform(() => vm.repository.react(post.id, emoji)),
                    itemBuilder: (_) => [
                      for (final emoji in ['💚', '🙌', '😊'])
                        PopupMenuItem(value: emoji, child: Text(emoji)),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _conversation(post.id),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                    ),
                    label: Text(
                      '${post.replies.length} תגובות',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _postOptions(BoardPost post) => PopupMenuButton<String>(
    tooltip: 'אפשרויות פרסום',
    iconSize: 18,
    padding: EdgeInsets.zero,
    onSelected: (value) => _postAction(value, post),
    itemBuilder: (_) => [
      if (post.mine) ...[
        const PopupMenuItem(value: 'edit', child: Text('עריכת פרסום')),
        PopupMenuItem(
          value: 'close',
          child: Text(
            post.closed
                ? 'פתיחה מחדש'
                : post.kind == PostKind.request
                ? 'סימון כנפתר'
                : 'לא רלוונטי יותר',
          ),
        ),
      ],
      if (vm.active?.isAdmin ?? false)
        PopupMenuItem(
          value: 'pin',
          child: Text(post.pinned ? 'ביטול נעיצה' : 'נעיצה בלוח'),
        ),
      if (post.mine || (vm.active?.isAdmin ?? false))
        const PopupMenuItem(value: 'delete', child: Text('מחיקת פרסום')),
      if (!post.mine && !(vm.active?.isAdmin ?? false))
        const PopupMenuItem(enabled: false, child: Text('פרסום של שכן')),
    ],
  );

  Widget _later(
    String eyebrow,
    String title,
    IconData icon,
    String description,
  ) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Eyebrow(eyebrow),
      const SizedBox(height: 10),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 28),
      GlassPanel(
        child: Column(
          children: [
            Icon(icon, size: 64, color: glassTeal),
            const SizedBox(height: 20),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
            const SizedBox(height: 20),
            const SoftTag('בשלב הבא', icon: Icons.schedule_rounded),
          ],
        ),
      ),
    ],
  );

  Widget _empty(String title, String text, VoidCallback action) => GlassPanel(
    child: Column(
      children: [
        const Icon(Icons.forum_outlined, color: glassTeal, size: 42),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: glassMuted),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: action, child: const Text('מתחילים כאן')),
      ],
    ),
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

  void _chooseBuilding() => _sheet(
    (ctx) => ListenableBuilder(
      listenable: vm,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('הבניינים שלי', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'בוחרים בית, ומקבלים רק את מה ששייך אליו.',
              style: TextStyle(color: glassMuted),
            ),
            const SizedBox(height: 20),
            for (final home in vm.homes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(
                      Icons.apartment_rounded,
                      color: glassTeal,
                    ),
                    title: Text(home.name),
                    subtitle: Text(
                      '${home.address} · ${_apartmentLabel(home)}',
                    ),
                    trailing: home.id == vm.active?.id
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: glassTeal,
                          )
                        : null,
                    onTap: () {
                      unawaited(
                        _perform(() => vm.select(home.id), refresh: false),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _create();
              },
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('יצירת בניין חדש'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _join();
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('הצטרפות עם קוד בניין'),
            ),
            if (widget.onSignOut != null)
              TextButton.icon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('יציאה מהחשבון'),
              ),
            if (vm.active?.isAdmin ?? false) ...[
              const SectionTitle('מזמינים את השכנים'),
              GlassPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'קוד ההצטרפות לבניין',
                            style: TextStyle(fontSize: 12, color: glassMuted),
                          ),
                          SelectableText(
                            vm.active!.code,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: glassTeal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: vm.active!.code),
                        );
                        if (mounted) _message('קוד הבניין הועתק');
                      },
                      tooltip: 'העתקת קוד',
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                vm.live
                    ? 'הקוד מאפשר בקשת הצטרפות; הגישה נפתחת לאחר אישור.'
                    : 'בתצוגה המקומית הקוד עובד באותה הפעלה בלבד.',
                style: TextStyle(fontSize: 12, color: glassMuted),
              ),
            ],
          ],
        ),
      ),
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

  void _create() => _sheet(
    (ctx) => _BuildingForm(
      onSave: (name, address, apartment, householdName) async {
        // Keep the existing RPC compatible; new buildings have no entrance division.
        await vm.create(
          name,
          address,
          apartment,
          1,
          householdName: householdName,
        );
        if (!ctx.mounted || !mounted) return;
        Navigator.pop(ctx);
      },
    ),
  );

  void _editHousehold() {
    final home = vm.active;
    if (home == null || !home.isApartmentAdmin) return;
    _sheet(
      (ctx) => _HouseholdForm(
        initialName: home.householdName,
        onSave: (name) async {
          await vm.run(() => vm.repository.setHousehold(home, name));
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _join() => _sheet(
    (ctx) => _JoinForm(
      repository: vm.repository,
      onApply: (home, apartment, floor, householdName) async {
        await vm.run(() async {
          await vm.repository.apply(
            home,
            apartment,
            floor: floor,
            householdName: householdName,
          );
        });
        if (!ctx.mounted || !mounted) return;
        Navigator.pop(ctx);
        _message('הבקשה נשלחה. נעדכן אותך כשההצטרפות תאושר.');
      },
    ),
  );

  void _applications() {
    final updates = <ApprovalUpdate>[];
    final queuedReadIds = <String>{};
    unawaited(
      _sheet(
        (ctx) => ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            for (final update in vm.approvalUpdates) {
              if (!updates.any((shown) => shown.id == update.id)) {
                updates.add(update);
              }
            }
            final unreadIds = vm.approvalUpdates
                .where((update) => !queuedReadIds.contains(update.id))
                .map((update) => update.id)
                .toList();
            if (unreadIds.isNotEmpty) {
              queuedReadIds.addAll(unreadIds);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!ctx.mounted) return;
                unawaited(
                  _perform(() => vm.repository.readApprovalUpdates(unreadIds)),
                );
              });
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'עדכונים ובקשות',
                    style: Theme.of(ctx).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'הגישה לתוכן הבניין נפתחת רק אחרי האישורים הנדרשים.',
                    style: TextStyle(color: glassMuted),
                  ),
                  const SizedBox(height: 20),
                  if (updates.isEmpty && vm.pending.isEmpty && vm.inbox.isEmpty)
                    const GlassPanel(
                      child: _FeatureLine(
                        Icons.check_circle_outline,
                        'הכול מעודכן',
                        'אין כרגע עדכונים חדשים או בקשות.',
                      ),
                    ),
                  for (final update in updates) ...[
                    GlassPanel(
                      key: ValueKey('approval-update-${update.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FeatureLine(
                            Icons.check_circle_outline,
                            'התקבלת לבניין',
                            'ההצטרפות ל${update.buildingName} אושרה. ברוכים הבאים!',
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: vm.busy
                                ? null
                                : () {
                                    Navigator.pop(ctx);
                                    unawaited(
                                      _perform(
                                        () => vm.select(update.buildingId),
                                        refresh: false,
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('לפתוח את הבניין'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (vm.pending.isNotEmpty)
                    const SectionTitle('בקשות ההצטרפות שלי'),
                  for (final application in [...vm.pending, ...vm.inbox]) ...[
                    _pendingCard(application),
                    const SizedBox(height: 12),
                    if (!vm.live)
                      const SoftTag(
                        'כלי בדיקה · הדמיית מנהלים',
                        icon: Icons.science_outlined,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!application.buildingApproved &&
                            (!vm.live || application.canApproveBuilding))
                          OutlinedButton(
                            onPressed: vm.busy
                                ? null
                                : () => _approve(application, true),
                            child: Text(
                              vm.live
                                  ? 'אישור כמנהל הבניין'
                                  : 'הדמיית אישור מנהל הבניין',
                            ),
                          ),
                        if (application.apartmentHasAdmin &&
                            !application.apartmentApproved &&
                            (!vm.live || application.canApproveApartment))
                          OutlinedButton(
                            onPressed: vm.busy
                                ? null
                                : () => _approve(application, false),
                            child: Text(
                              vm.live
                                  ? 'אישור כמנהל הדירה'
                                  : 'הדמיית אישור מנהל הדירה',
                            ),
                          ),
                      ],
                    ),
                    if (application.mine)
                      TextButton(
                        onPressed: vm.busy
                            ? null
                            : () => _perform(
                                () => vm.repository.withdraw(application.id),
                              ),
                        child: const Text('ביטול הבקשה'),
                      ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pendingCard(JoinApplication a) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.building.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        if (!a.mine)
          Text(
            a.applicantName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: glassTeal,
            ),
          ),
        Text('דירה ${a.apartment}', style: const TextStyle(color: glassMuted)),
        const SizedBox(height: 14),
        _approvalLine('מנהל הבניין', a.buildingApproved),
        if (a.apartmentHasAdmin) ...[
          const SizedBox(height: 8),
          _approvalLine('מנהל הדירה', a.apartmentApproved),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            a.mine
                ? 'דירה חדשה: לאחר אישור הבניין תהיה מנהל הדירה הראשון.'
                : 'דירה חדשה: המצטרף הראשון יהפוך למנהל הדירה.',
            style: TextStyle(fontSize: 12, color: glassMuted),
          ),
        ],
      ],
    ),
  );
  Widget _approvalLine(String label, bool approved) => Row(
    children: [
      Icon(
        approved ? Icons.check_circle_outline : Icons.schedule_rounded,
        size: 18,
        color: approved ? glassTeal : glassMuted,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(
        approved ? 'אושר' : 'ממתין לאישור',
        style: TextStyle(
          color: approved ? glassTeal : glassMuted,
          fontSize: 12,
        ),
      ),
    ],
  );
  Future<void> _approve(JoinApplication a, bool building) async {
    final succeeded = await _perform(
      () => vm.repository.approve(a.id, byBuildingAdmin: building),
    );
    if (!succeeded || !mounted) return;
    if (a.mine && vm.homes.any((h) => h.id == a.building.id)) {
      await _perform(() => vm.select(a.building.id), refresh: false);
      _message('ההצטרפות אושרה. אפשר לעבור לבניין החדש למעלה.');
    }
  }

  void _compose({BoardPost? post}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final home = vm.active;
    if (home == null) {
      _chooseBuilding();
      return;
    }
    _sheet(
      (ctx) => _PostForm(
        post: post,
        onSave: (text, kind) async {
          await vm.run(
            () => post == null
                ? vm.repository.publish(home, text, kind)
                : vm.repository.edit(post.id, text),
          );
          if (!ctx.mounted || !mounted) return;
          Navigator.pop(ctx);
          if (post == null) timelineKey.currentState?.showLatest();
        },
      ),
    );
  }

  void _conversation(String id) =>
      _sheet((ctx) => _Conversation(vm: vm, postId: id));
  Future<void> _postAction(String action, BoardPost post) async {
    switch (action) {
      case 'edit':
        _compose(post: post);
      case 'close':
        await _perform(() => vm.repository.close(post.id));
      case 'pin':
        await _perform(() => vm.repository.pin(post.id, vm.active!));
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('למחוק את הפרסום?'),
            content: const Text('גם התגובות לפרסום יימחקו.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('להשאיר'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('למחוק'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _perform(() => vm.repository.remove(post.id, vm.active!));
        }
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
  if (elapsed.inMinutes < 60) return 'לפני ${elapsed.inMinutes} דקות';
  if (elapsed.inHours < 24) return 'לפני ${elapsed.inHours} שעות';
  return 'לפני ${elapsed.inDays} ימים';
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.icon, this.title, this.description);
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: glassTeal.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: glassTeal, size: 24),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: glassMuted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(26),
    child: GlassPanel(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: glassTeal, size: 28),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: glassMuted),
          ),
        ],
      ),
    ),
  );
}

class _HouseholdForm extends StatefulWidget {
  const _HouseholdForm({required this.initialName, required this.onSave});
  final String initialName;
  final Future<void> Function(String) onSave;
  @override
  State<_HouseholdForm> createState() => _HouseholdFormState();
}

class _HouseholdFormState extends State<_HouseholdForm>
    with _AsyncForm<_HouseholdForm> {
  late final name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('שם הבית שלכם', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'שם משותף לבני הבית, למשל משפחת כהן. אפשר להשאיר ריק.',
          style: TextStyle(color: glassMuted),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('household-name'),
          controller: name,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'שם הבית'),
        ),
        if (submitError != null)
          Text(submitError!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: submitting
              ? null
              : () => submit(() => widget.onSave(name.text)),
          child: Text(submitting ? 'שומרים…' : 'שמירת שם הבית'),
        ),
      ],
    ),
  );
}

class _BuildingForm extends StatefulWidget {
  const _BuildingForm({required this.onSave});
  final Future<void> Function(String, String, String, String) onSave;
  @override
  State<_BuildingForm> createState() => _BuildingFormState();
}

class _BuildingFormState extends State<_BuildingForm>
    with _AsyncForm<_BuildingForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      address = TextEditingController(),
      apartment = TextEditingController(),
      householdName = TextEditingController();
  @override
  void dispose() {
    name.dispose();
    address.dispose();
    apartment.dispose();
    householdName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('בית חדש ב$appNameHebrew'),
          const SizedBox(height: 8),
          Text(
            'נעים להכיר, שכנים.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'כמה פרטים והבניין מוכן. אין צורך להזין מראש את כל הדירות.',
            style: TextStyle(color: glassMuted),
          ),
          const SizedBox(height: 24),
          AddressPicker(onChanged: (value) => address.text = value),
          const SizedBox(height: 14),
          _field(
            name,
            'שם הבניין · לא חובה',
            'אם משאירים ריק, תוצג הכתובת',
            required: false,
            maxLength: 100,
            key: const Key('building-name'),
          ),
          const SizedBox(height: 14),
          _apartmentField(apartment, key: const Key('building-apartment')),
          const SizedBox(height: 14),
          _field(
            householdName,
            'שם הבית שלך · לא חובה',
            'למשל: משפחת כהן',
            required: false,
            maxLength: 60,
            key: const Key('building-household-name'),
          ),
          const SizedBox(height: 22),
          if (submitError != null)
            Text(submitError!, style: const TextStyle(color: Colors.red)),
          const GlassPanel(
            child: _FeatureLine(
              Icons.verified_user_outlined,
              'אתה המנהל הראשון',
              'תקבל הרשאות מנהל בניין, ועד ומנהל הדירה שלך. בהמשך תוכל לצרף מנהלים נוספים.',
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('building-create-submit'),
              onPressed: submitting
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        submit(
                          () => widget.onSave(
                            name.text,
                            address.text,
                            normalizeApartment(apartment.text),
                            householdName.text,
                          ),
                        );
                      }
                    },
              child: Text(submitting ? 'יוצרים…' : 'יוצרים את הבניין'),
            ),
          ),
        ],
      ),
    ),
  );
}

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

class _JoinForm extends StatefulWidget {
  const _JoinForm({required this.repository, required this.onApply});
  final BuildingRepository repository;
  final Future<void> Function(BuildingHome, String, String?, String) onApply;
  @override
  State<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<_JoinForm> with _AsyncForm<_JoinForm> {
  final form = GlobalKey<FormState>();
  final code = TextEditingController(),
      apartment = TextEditingController(),
      floor = TextEditingController(),
      household = TextEditingController();
  BuildingHome? found;
  ApartmentStatus? status;
  String? error, lookupError;
  Timer? debounce;
  int lookupVersion = 0;
  bool checkingApartment = false;

  void _resetApartment() {
    debounce?.cancel();
    lookupVersion++;
    status = null;
    lookupError = null;
    checkingApartment = false;
    household.clear();
  }

  void _queueApartmentCheck() {
    setState(_resetApartment);
    if (found == null || !RegExp(r'^[0-9]+$').hasMatch(apartment.text)) return;
    setState(() => checkingApartment = true);
    final version = lookupVersion;
    debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final result = await widget.repository.apartmentStatus(
          found!,
          apartment.text,
        );
        if (!mounted || version != lookupVersion) return;
        setState(() {
          status = result;
          checkingApartment = false;
        });
      } catch (error) {
        if (!mounted || version != lookupVersion) return;
        setState(() {
          lookupError = buildingErrorMessage(error);
          checkingApartment = false;
        });
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    code.dispose();
    apartment.dispose();
    floor.dispose();
    household.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('מצטרפים לשכנים'),
          const SizedBox(height: 8),
          Text(
            'יש לך מקום כאן.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'מזינים את הקוד שקיבלת ממנהל הבניין.',
            style: TextStyle(color: glassMuted),
          ),
          const SizedBox(height: 22),
          TextField(
            key: const Key('join-code'),
            controller: code,
            enabled: !submitting,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'קוד בניין',
              errorText: error,
            ),
            onChanged: (_) => setState(() {
              found = null;
              error = null;
              _resetApartment();
            }),
          ),
          const SizedBox(height: 10),
          if (!widget.repository.isRemote)
            const Text(
              'קוד לבדיקה: NEIGHBOR. בדירות 1, 2 ו־12 יש מנהל דירה.',
              style: TextStyle(fontSize: 12, color: glassMuted),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: submitting
                ? null
                : () => submit(() async {
                    final result = await widget.repository.resolveCode(
                      code.text,
                    );
                    if (!mounted) return;
                    setState(() {
                      _resetApartment();
                      found = result;
                      error = found == null
                          ? 'לא נמצא בניין עם הקוד הזה'
                          : null;
                    });
                    _queueApartmentCheck();
                  }),
            child: const Text('בדיקת הקוד'),
          ),
          if (submitError != null)
            Text(submitError!, style: const TextStyle(color: Colors.red)),
          if (found != null) ...[
            const SizedBox(height: 18),
            GlassPanel(
              child: _FeatureLine(
                Icons.apartment_rounded,
                found!.name,
                found!.address,
              ),
            ),
            const SizedBox(height: 18),
            _apartmentField(
              apartment,
              key: const Key('join-apartment'),
              onChanged: (_) => _queueApartmentCheck(),
            ),
            const SizedBox(height: 12),
            if (checkingApartment)
              const Text(
                'בודקים את הדירה…',
                style: TextStyle(color: glassMuted),
              ),
            if (lookupError != null) ...[
              Text(lookupError!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: _queueApartmentCheck,
                child: const Text('בדיקת הדירה מחדש'),
              ),
            ],
            if (status != null) ...[
              GlassPanel(
                child: _FeatureLine(
                  status!.exists
                      ? Icons.verified_user_outlined
                      : Icons.home_outlined,
                  status!.exists ? 'מצטרפים לבית קיים' : 'בית חדש בבניין',
                  status!.hasAdmin
                      ? 'הבקשה תועבר לאישור מנהל הבניין ומנהל הבית. נדרשים שני האישורים לפני פתיחת הגישה.'
                      : status!.exists
                      ? 'הבקשה תועבר לאישור מנהל הבניין. שם הבית הקיים נשמר.'
                      : 'לאחר אישור מנהל הבניין תהיו מנהלי הבית הראשונים.',
                ),
              ),
              if (!status!.exists) ...[
                const SizedBox(height: 14),
                _field(
                  household,
                  'שם הבית · לא חובה',
                  'למשל: משפחת כהן',
                  required: false,
                  maxLength: 60,
                  key: const Key('join-household-name'),
                ),
              ],
            ],
            const SizedBox(height: 14),
            _field(floor, 'קומה · לא חובה', '', required: false, maxLength: 20),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('join-submit'),
                onPressed: submitting || status == null || checkingApartment
                    ? null
                    : () {
                        if (form.currentState!.validate()) {
                          submit(
                            () => widget.onApply(
                              found!,
                              normalizeApartment(apartment.text),
                              floor.text.trim(),
                              status!.exists ? '' : household.text.trim(),
                            ),
                          );
                        }
                      },
                child: const Text('שליחת בקשת הצטרפות'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _PostForm extends StatefulWidget {
  const _PostForm({this.post, required this.onSave});
  final BoardPost? post;
  final Future<void> Function(String, PostKind) onSave;
  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> with _AsyncForm<_PostForm> {
  late final text = TextEditingController(text: widget.post?.text ?? '');
  late PostKind kind = widget.post?.kind ?? PostKind.notice;
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('רק לשכנים בבניין שלך'),
          const SizedBox(height: 8),
          Text(
            widget.post == null ? 'מה תרצה לשתף?' : 'עריכת הפרסום',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          if (widget.post == null)
            SegmentedButton<PostKind>(
              segments: const [
                ButtonSegment(
                  value: PostKind.notice,
                  label: Text('מודעה'),
                  icon: Icon(Icons.campaign_outlined),
                ),
                ButtonSegment(
                  value: PostKind.request,
                  label: Text('בקשת עזרה'),
                  icon: Icon(Icons.waving_hand_outlined),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('board-post-text'),
            controller: text,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: kind == PostKind.request
                  ? 'איזו עזרה תשמח לקבל?'
                  : 'עדכון קטן, שאלה או משהו טוב שקרה…',
            ),
            validator: (v) => (v?.trim().isEmpty ?? true)
                ? 'יש לכתוב משהו לפני הפרסום'
                : null,
          ),
          const SizedBox(height: 20),
          if (submitError != null)
            Text(submitError!, style: const TextStyle(color: Colors.red)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('board-post-submit'),
              onPressed: submitting
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        submit(() => widget.onSave(text.text.trim(), kind));
                      }
                    },
              child: Text(widget.post == null ? 'פרסום בלוח' : 'שמירת השינוי'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Conversation extends StatefulWidget {
  const _Conversation({required this.vm, required this.postId});
  final BuildingViewModel vm;
  final String postId;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation>
    with _AsyncForm<_Conversation> {
  final reply = TextEditingController();
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vm,
    builder: (context, _) {
      final post = widget.vm.posts
          .where((p) => p.id == widget.postId)
          .firstOrNull;
      if (post == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('הפרסום אינו זמין בבניין הנוכחי.'),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 260;
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, compact ? 8 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'השיחה על הפרסום',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'סגירת שיחה',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: ListView(
                      children: [
                        GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(post.text),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (post.replies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'עוד אין תגובות. אפשר להתחיל את השיחה.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final r in post.replies)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassPanel(
                              padding: const EdgeInsets.all(16),
                              tint: r.author == 'אני'
                                  ? const Color(0xFFD8F0ED)
                                  : Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.author,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: glassTeal,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(r.text),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  if (submitError != null)
                    Text(
                      submitError!,
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (post.closed)
                    const Text(
                      'הפרסום סגור לתגובות. הכותב יכול לפתוח אותו מחדש.',
                      style: TextStyle(color: glassMuted),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: reply,
                            minLines: 1,
                            maxLines: compact ? 1 : 3,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'כותבים לשכנים…',
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'שליחת תגובה',
                          onPressed: submitting || reply.text.trim().isEmpty
                              ? null
                              : () => submit(() async {
                                  await widget.vm.run(
                                    () => widget.vm.repository.reply(
                                      post.id,
                                      reply.text,
                                    ),
                                  );
                                  if (!mounted) return;
                                  reply.clear();
                                  setState(() {});
                                }),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        if (compact)
                          IconButton(
                            tooltip: 'סגירת שיחה',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

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
