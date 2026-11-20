import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../data/building/parking_repository.dart';
import 'glass_widgets.dart';

String parkingTime(DateTime date) =>
    '\u2066${date.day}.${date.month} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}\u2069';

const parkingDayLetters = {
  DateTime.sunday: 'א׳',
  DateTime.monday: 'ב׳',
  DateTime.tuesday: 'ג׳',
  DateTime.wednesday: 'ד׳',
  DateTime.thursday: 'ה׳',
  DateTime.friday: 'ו׳',
  DateTime.saturday: 'ש׳',
};
const parkingDayNames = {
  DateTime.sunday: 'ראשון',
  DateTime.monday: 'שני',
  DateTime.tuesday: 'שלישי',
  DateTime.wednesday: 'רביעי',
  DateTime.thursday: 'חמישי',
  DateTime.friday: 'שישי',
  DateTime.saturday: 'שבת',
};

/// Sunday first, as on an Israeli calendar.
const parkingWeekOrder = [
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

/// The windows of a regular schedule: on each chosen weekday, [from]–[to],
/// starting today, for [weeks] weeks. An end at or before the start means the
/// window runs past midnight. Windows already over are skipped, and one that
/// has already begun starts now.
List<ParkingWindow> regularParkingWindows({
  required Set<int> days,
  required TimeOfDay from,
  required TimeOfDay to,
  required int weeks,
  required DateTime now,
}) {
  final overnight = to.hour * 60 + to.minute <= from.hour * 60 + from.minute;
  return [
        for (var d = 0; d < weeks * 7; d++)
          if (days.contains(DateTime(now.year, now.month, now.day + d).weekday))
            (
              start: DateTime(
                now.year,
                now.month,
                now.day + d,
                from.hour,
                from.minute,
              ),
              end: DateTime(
                now.year,
                now.month,
                now.day + d + (overnight ? 1 : 0),
                to.hour,
                to.minute,
              ),
            ),
      ]
      .where((w) => w.end.isAfter(now))
      .map(
        (w) => w.start.isBefore(now)
            ? (
                start: DateTime(
                  now.year,
                  now.month,
                  now.day,
                  now.hour,
                  now.minute,
                ),
                end: w.end,
              )
            : w,
      )
      .toList();
}

String _clock(TimeOfDay t) =>
    '\u2066${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}\u2069';

String _dayAndTime(DateTime t) =>
    'יום ${parkingDayNames[t.weekday]} ${t.day}.${t.month} בשעה ${_clock(TimeOfDay.fromDateTime(t))}';

/// "א׳–ה׳", "כל יום", or the letters of the chosen days.
String parkingDaysLabel(Set<int> days) {
  if (days.length == 7) return 'כל יום';
  const workweek = {1, 2, 3, 4, 7};
  if (days.length == 5 && days.containsAll(workweek)) return 'א׳–ה׳';
  return [
    for (final d in parkingWeekOrder)
      if (days.contains(d)) parkingDayLetters[d]!,
  ].join(' ');
}

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({
    super.key,
    required this.repository,
    required this.buildingId,
    required this.apartment,
  });
  final ParkingRepository repository;
  final String buildingId, apartment;
  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen>
    with WidgetsBindingObserver {
  late final model = ParkingViewModel(widget.repository, widget.buildingId)
    ..load();
  Timer? timer;
  int section = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  void _refresh() {
    if (!model.loading && !model.saving) unawaited(model.load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _startTimer();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    model.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _remove(ParkingSpace space) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('להסיר את חניה ${space.label}?'),
        content: const Text(
          'זמנים פנויים שפורסמו לחניה יבוטלו. ההיסטוריה נשמרת, ואפשר להוסיף את החניה שוב בהמשך.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('חזרה'),
          ),
          FilledButton(
            key: const Key('parking-remove-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('הסרת החניה'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await model.run(() => model.repository.removeSpace(space.id));
    if (mounted) _message(ok ? 'החניה הוסרה' : model.error ?? 'הפעולה נכשלה');
  }

  Future<void> _editor([ParkingSpace? space, bool details = false]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: ParkingEditor(
          model: model,
          apartment: widget.apartment,
          space: space,
          details: details,
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => section = 1);
      _message(
        space == null
            ? 'החניה נוספה לדירה'
            : details
            ? 'פרטי החניה עודכנו'
            : 'הזמינות פורסמה לשכנים',
      );
    }
  }

  Future<void> _act(ParkingOffer offer, {required bool cancel}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          cancel
              ? (offer.ownSpace ? 'לבטל את שיתוף החניה?' : 'לבטל את ההזמנה?')
              : 'להזמין את חניה ${offer.space.label}?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'מ־${parkingTime(offer.startsAt)}\nעד ${parkingTime(offer.endsAt)}',
            ),
            const SizedBox(height: Space.m),
            Text(
              cancel
                  ? (offer.ownSpace
                        ? 'הפרסום ייסגר. אם החניה כבר הוזמנה, גם ההזמנה תבוטל והמזמין יראה את הביטול.'
                        : 'החניה תחזור להיות פנויה לשכנים לכל הטווח.')
                  : 'השיתוף בחינם. כל הטווח יישמר לך מיד, ללא אישור נוסף.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('חזרה'),
          ),
          FilledButton(
            key: const Key('parking-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cancel ? 'אישור ביטול' : 'הזמנה בחינם'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await model.run(
      () => cancel
          ? widget.repository.cancel(offer.id)
          : widget.repository.book(offer.id),
    );
    if (!mounted) return;
    if (ok) {
      if (!cancel) setState(() => section = 2);
      _message(cancel ? 'הביטול נשמר' : 'החניה הוזמנה עבורך');
    } else {
      _message(model.error ?? 'הפעולה לא הושלמה');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final now = DateTime.now();
      final offers = model.snapshot.offers
          .where((o) => o.endsAt.isAfter(now))
          .where(
            (o) => switch (section) {
              0 => o.canBook,
              1 => o.ownSpace,
              2 => o.myBooking,
              _ => false,
            },
          )
          .toList();
      return RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          key: const Key('parking-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Eyebrow('מפנים מקום לשכנים'),
            const SizedBox(height: Space.xs),
            Text(
              'החניון שלנו',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.s),
            Text(
              'חניה פנויה אצלך? לשכן זה יכול לעשות את היום.',
              style: TextStyle(color: context.glass.muted),
            ),
            const SizedBox(height: Space.m),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('parking-add'),
                onPressed: model.saving ? null : () => _editor(),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('הוספת חניה לדירה'),
              ),
            ),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 4; i++)
                  ChoiceChip(
                    key: ValueKey('parking-section-$i'),
                    selected: section == i,
                    onSelected: (_) {
                      setState(() => section = i);
                      if (i == 3) unawaited(model.loadHistory());
                    },
                    label: Text(
                      ['פנויות', 'החניות שלנו', 'ההזמנות שלי', 'היסטוריה'][i],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            if (model.loading || model.saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (model.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.error!),
                      TextButton(
                        onPressed: model.loading || model.saving
                            ? null
                            : model.load,
                        child: const Text('ניסיון נוסף'),
                      ),
                    ],
                  ),
                ),
              ),
            if (section == 1) ...[
              for (final space in model.snapshot.spaces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _spaceTitle(space, 'של דירה ${widget.apartment}'),
                        const SizedBox(height: Space.m),
                        OutlinedButton.icon(
                          key: ValueKey('parking-share-${space.id}'),
                          onPressed: model.saving ? null : () => _editor(space),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('שיתוף זמן פנוי'),
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              key: ValueKey('parking-edit-${space.id}'),
                              onPressed: model.saving
                                  ? null
                                  : () => _editor(space, true),
                              child: const Text('עריכת פרטים'),
                            ),
                            TextButton(
                              key: ValueKey('parking-remove-${space.id}'),
                              onPressed: model.saving
                                  ? null
                                  : () => _remove(space),
                              child: const Text('הסרה'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (offers.isNotEmpty) const SectionTitle('הזמנים ששיתפנו'),
            ],
            if (section == 3)
              for (final past in model.history)
                Padding(
                  key: ValueKey('parking-history-${past.id}'),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _spaceTitle(
                          past.space,
                          past.ownSpace
                              ? 'החניה שלנו'
                              : 'של דירה ${past.apartment}',
                        ),
                        const SizedBox(height: Space.s),
                        Text(
                          'מ־${parkingTime(past.startsAt)} עד ${parkingTime(past.endsAt)}',
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          _historyStatus(past),
                          style: TextStyle(
                            color: context.glass.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            for (final offer in offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _offerCard(offer),
              ),
            if (!model.loading &&
                model.error == null &&
                offers.isEmpty &&
                (section != 3 || model.history.isEmpty) &&
                (section != 1 || model.snapshot.spaces.isEmpty))
              GlassPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_parking_rounded,
                      color: context.glass.accent,
                      size: 34,
                    ),
                    const SizedBox(height: Space.m),
                    Text(
                      [
                        'עדיין אין חניות פנויות',
                        'החניות של הבית, במקום אחד',
                        'עוד אין לך הזמנות',
                        'עוד אין היסטוריה',
                      ][section],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      [
                        'כששכן ישתף חניה, אפשר יהיה להזמין אותה כאן.',
                        'מוסיפים חניה פעם אחת. כל בני הבית יוכלו לשתף אותה כשהיא פנויה.',
                        'חניה שהזמנת תופיע כאן עם השעות והמיקום.',
                        'שיתופים והזמנות שהסתיימו או בוטלו יופיעו כאן.',
                      ][section],
                      style: TextStyle(color: context.glass.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  String _historyStatus(ParkingOffer o) {
    final who = o.bookerName.isEmpty ? '' : ' · ${o.bookerName}';
    if (o.bookingStatus == 'confirmed') return 'הוזמנה$who';
    if (o.bookingStatus == 'cancelled') return 'ההזמנה בוטלה$who';
    return o.status == 'cancelled' ? 'השיתוף בוטל' : 'לא הוזמנה';
  }

  Widget _spaceTitle(ParkingSpace space, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.glass.chip,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.local_parking_rounded, color: context.glass.accent),
      ),
      const SizedBox(width: Space.m),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'חניה ${space.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '$subtitle${space.level.isEmpty ? '' : ' · מפלס \u2066${space.level}\u2069'}',
              style: TextStyle(fontSize: 12, color: context.glass.muted),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _offerCard(ParkingOffer o) => GlassPanel(
    key: ValueKey('parking-offer-${o.id}'),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _spaceTitle(o.space, 'דירה ${o.apartment}'),
        const SizedBox(height: Space.l),
        Text(
          'מ־${parkingTime(o.startsAt)}\nעד ${parkingTime(o.endsAt)}',
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.7),
        ),
        if (o.space.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              o.space.notes,
              style: TextStyle(color: context.glass.muted),
            ),
          ),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SoftTag(
              o.status == 'cancelled'
                  ? 'השיתוף בוטל'
                  : o.status == 'booked'
                  ? (o.myBooking
                        ? 'מוזמנת עבורך'
                        : 'הוזמנה${o.bookerName.isEmpty ? '' : ' · ${o.bookerName}'}')
                  : o.myBooking && o.bookingStatus == 'cancelled'
                  ? 'ההזמנה בוטלה · החניה פנויה'
                  : 'שיתוף בחינם',
              icon: o.status == 'booked'
                  ? Icons.check_circle_outline_rounded
                  : Icons.favorite_border_rounded,
            ),
          ],
        ),
        if (o.canBook || o.canCancel)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (o.canBook)
                  FilledButton(
                    key: ValueKey('parking-book-${o.id}'),
                    onPressed: model.saving
                        ? null
                        : () => _act(o, cancel: false),
                    child: const Text('הזמנה לכל הטווח'),
                  ),
                if (o.canCancel)
                  TextButton(
                    key: ValueKey('parking-cancel-${o.id}'),
                    onPressed: model.saving
                        ? null
                        : () => _act(o, cancel: true),
                    child: Text(o.ownSpace ? 'ביטול השיתוף' : 'ביטול ההזמנה'),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class ParkingEditor extends StatefulWidget {
  const ParkingEditor({
    super.key,
    required this.model,
    required this.apartment,
    this.space,
    this.details = false,
  });
  final ParkingViewModel model;
  final String apartment;
  final ParkingSpace? space;

  /// Edits the space itself instead of publishing a window for it.
  final bool details;
  @override
  State<ParkingEditor> createState() => _ParkingEditorState();
}

class _ParkingEditorState extends State<ParkingEditor> {
  final form = GlobalKey<FormState>();
  late final label = TextEditingController(text: widget.space?.label ?? ''),
      level = TextEditingController(text: widget.space?.level ?? ''),
      notes = TextEditingController(text: widget.space?.notes ?? '');
  bool get describing => widget.space == null || widget.details;

  /// false: one continuous stretch (start to end, may span days).
  /// true: the same hours on chosen weekdays, for a number of weeks.
  bool regular = false;
  Set<int> days = {1, 2, 3, 4, 7};
  TimeOfDay dailyFrom = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay dailyTo = const TimeOfDay(hour: 14, minute: 0);
  int weeks = 4;

  /// Week counts on offer; 4 weeks of every day is 28 windows, under the
  /// server's limit of 31 per publish.
  static const weekChoices = {1: 'השבוע', 2: 'שבועיים', 4: 'חודש'};

  List<ParkingWindow> _windows() => regularParkingWindows(
    days: days,
    from: dailyFrom,
    to: dailyTo,
    weeks: weeks,
    now: DateTime.now(),
  );

  late DateTime start = _initialStart();
  DateTime _initialStart() {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 15));
  }

  late DateTime end = start.add(const Duration(hours: 2));
  bool saving = false;
  String? error;
  @override
  void dispose() {
    label.dispose();
    level.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final value = from ? start : end;
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: value.isBefore(today) ? today : value,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() {
      final picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (from) {
        // Moving the start past the end keeps the chosen length instead of
        // leaving an invalid range for the user to discover on save.
        if (!end.isAfter(picked)) {
          end = picked.add(
            end.isAfter(start)
                ? end.difference(start)
                : const Duration(hours: 2),
          );
        }
        start = picked;
      } else {
        end = picked;
      }
    });
  }

  Future<void> _pickDaily(bool from) async {
    final time = await showTimePicker(
      context: context,
      initialTime: from ? dailyFrom : dailyTo,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    setState(() => from ? dailyFrom = time : dailyTo = time);
  }

  String get _summary {
    if (!regular) {
      return 'פנויה מ${_dayAndTime(start)} עד ${_dayAndTime(end)}.';
    }
    final n = _windows().length;
    return 'פנויה ב${days.length == 7 ? 'כל יום' : 'ימים ${parkingDaysLabel(days)}'}, '
        'בין ${_clock(dailyFrom)} ל־${_clock(dailyTo)}, ${weekChoices[weeks] == 'השבוע' ? 'השבוע' : 'במשך ${weekChoices[weeks]}'} '
        '(${n == 1 ? 'פעם אחת' : '$n פעמים'}).';
  }

  bool get _spaceDetailsChanged =>
      widget.space != null &&
      (level.text.trim() != widget.space!.level ||
          notes.text.trim() != widget.space!.notes);

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    if (!describing && regular) {
      if (days.isEmpty) {
        setState(() => error = 'יש לבחור לפחות יום אחד.');
        return;
      }
      if (_windows().isEmpty) {
        setState(() => error = 'אין מועד עתידי בטווח שבחרת.');
        return;
      }
    }
    if (!describing &&
        !regular &&
        (!end.isAfter(start) ||
            !end.isAfter(DateTime.now()) ||
            start.isBefore(
              DateTime.now().subtract(const Duration(minutes: 5)),
            ) ||
            start.isAfter(DateTime.now().add(const Duration(days: 90))) ||
            end.difference(start) > const Duration(days: 90))) {
      setState(() => error = 'יש לבחור טווח עתידי תקין של עד 90 יום.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.model.run(
      () => widget.space == null
          ? widget.model.repository.addSpace(
              widget.model.buildingId,
              label.text,
              level.text,
              notes.text,
            )
          : widget.details
          ? widget.model.repository.updateSpace(
              widget.space!.id,
              label.text,
              level.text,
              notes.text,
            )
          : _publish(),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        saving = false;
        error = widget.model.error;
      });
    }
  }

  /// Saves changed "where is it" notes on the space, then publishes.
  Future<void> _publish() async {
    final repo = widget.model.repository;
    final space = widget.space!;
    if (_spaceDetailsChanged) {
      await repo.updateSpace(space.id, space.label, level.text, notes.text);
    }
    if (regular) {
      await repo.publishSeries(space.id, _windows());
    } else {
      await repo.publish(space.id, start, end);
    }
  }

  Widget _step(int n, String title) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: context.glass.chip,
          foregroundColor: context.glass.accent,
          child: Text(
            '$n',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: Space.s),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.space == null
                  ? 'החניה של הבית'
                  : widget.details
                  ? 'פרטי חניה ${widget.space!.label}'
                  : 'משתפים את חניה ${widget.space!.label}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.s),
            Text(
              widget.space == null
                  ? 'החניה תשויך לדירה ${widget.apartment}. כל בני הבית יוכלו לנהל את השיתוף.'
                  : 'בוחרים מתי, מוסיפים איפה, ומפרסמים. השכנים יראו את החניה בלשונית ״פנויות״.',
              style: TextStyle(color: context.glass.muted),
            ),
            const SizedBox(height: Space.xxl),
            if (describing) ...[
              TextFormField(
                key: const Key('parking-label'),
                controller: label,
                enabled: !saving,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'מספר או סימון החניה',
                  hintText: 'למשל 42 או א׳־12',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'יש להזין סימון חניה'
                    : null,
              ),
              const SizedBox(height: Space.m),
              TextFormField(
                key: const Key('parking-level'),
                controller: level,
                enabled: !saving,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'מפלס (לא חובה)',
                  hintText: 'למשל ‎-1',
                ),
              ),
              const SizedBox(height: Space.m),
              TextFormField(
                key: const Key('parking-notes'),
                controller: notes,
                enabled: !saving,
                maxLength: 200,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'איך מוצאים אותה? (לא חובה)',
                  hintText: 'למשל ליד המעלית',
                ),
              ),
            ] else ...[
              _step(1, 'מתי החניה פנויה?'),
              SegmentedButton<bool>(
                key: const Key('parking-mode'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.flight_takeoff_rounded),
                    label: Text('ברצף'),
                    tooltip: 'למשל: נוסע, פנויה מחמישי עד שלישי',
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.event_repeat_rounded),
                    label: Text('בימים קבועים'),
                    tooltip: 'למשל: בעבודה א׳–ה׳ 7:00–14:00',
                  ),
                ],
                selected: {regular},
                onSelectionChanged: saving
                    ? null
                    : (v) => setState(() {
                        regular = v.first;
                        error = null;
                      }),
              ),
              const SizedBox(height: Space.m),
              if (!regular) ...[
                OutlinedButton.icon(
                  key: const Key('parking-start'),
                  onPressed: saving ? null : () => _pick(true),
                  icon: const Icon(Icons.event_available_outlined),
                  label: Text('מ${_dayAndTime(start)}'),
                ),
                const SizedBox(height: Space.s),
                OutlinedButton.icon(
                  key: const Key('parking-end'),
                  onPressed: saving ? null : () => _pick(false),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: Text('עד ${_dayAndTime(end)}'),
                ),
              ] else ...[
                Text(
                  'באילו ימים?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    for (final d in parkingWeekOrder)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _DayToggle(
                            key: ValueKey('parking-day-$d'),
                            letter: parkingDayLetters[d]!,
                            name: parkingDayNames[d]!,
                            selected: days.contains(d),
                            onTap: saving
                                ? null
                                : () => setState(() {
                                    days = {...days};
                                    days.contains(d)
                                        ? days.remove(d)
                                        : days.add(d);
                                  }),
                          ),
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      key: const Key('parking-days-workweek'),
                      onPressed: saving
                          ? null
                          : () => setState(() => days = {1, 2, 3, 4, 7}),
                      child: const Text('א׳–ה׳'),
                    ),
                    TextButton(
                      key: const Key('parking-days-all'),
                      onPressed: saving
                          ? null
                          : () => setState(() => days = {...parkingWeekOrder}),
                      child: const Text('כל יום'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.s),
                Text(
                  'באילו שעות?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('parking-daily-from'),
                        onPressed: saving ? null : () => _pickDaily(true),
                        child: Text('מ־${_clock(dailyFrom)}'),
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('parking-daily-to'),
                        onPressed: saving ? null : () => _pickDaily(false),
                        child: Text('עד ${_clock(dailyTo)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.m),
                Text('לכמה זמן?', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in weekChoices.entries)
                      ChoiceChip(
                        key: ValueKey('parking-weeks-${e.key}'),
                        selected: weeks == e.key,
                        onSelected: saving
                            ? null
                            : (_) => setState(() => weeks = e.key),
                        label: Text(e.value),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: Space.xxl),
              _step(2, 'איפה היא? (לא חובה)'),
              TextFormField(
                key: const Key('parking-level'),
                controller: level,
                enabled: !saving,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: 'מפלס',
                  hintText: 'למשל ‎-1',
                ),
              ),
              const SizedBox(height: Space.s),
              TextFormField(
                key: const Key('parking-notes'),
                controller: notes,
                enabled: !saving,
                maxLength: 200,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'הערות לשכנים',
                  hintText: 'למשל: שורה ג׳, ליד המעלית',
                ),
              ),
              const SizedBox(height: Space.l),
              GlassPanel(
                key: const Key('parking-summary'),
                tone: GlassTone.accent,
                padding: const EdgeInsets.all(Space.l),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_parking_rounded,
                      color: context.glass.accent,
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        'חניה ${widget.space!.label}: $_summary\nבחינם, וכל שכן יכול להזמין בלחיצה.',
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: context.glass.error),
                ),
              ),
            const SizedBox(height: Space.xxl),
            FilledButton(
              key: const Key('parking-save'),
              onPressed: saving ? null : _save,
              child: Text(
                saving
                    ? 'שומרים…'
                    : widget.space == null
                    ? 'הוספת החניה'
                    : widget.details
                    ? 'שמירת הפרטים'
                    : 'פרסום לשכנים',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

@Preview(name: 'נייבור · חניון', size: Size(390, 844))
Widget parkingPreview() => MaterialApp(
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: ParkingScreen(
            repository: _ParkingPreviewRepository(),
            buildingId: 'preview',
            apartment: '12',
          ),
        ),
      ),
    ),
  ),
);

class _ParkingPreviewRepository implements ParkingRepository {
  @override
  Future<ParkingSnapshot> load(String buildingId) async => ParkingSnapshot(
    offers: [
      ParkingOffer(
        id: 'preview',
        space: const ParkingSpace(
          id: 'preview',
          label: '24',
          level: '-1',
          notes: 'מימין למעלית',
        ),
        apartment: '8',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
        endsAt: DateTime.now().add(const Duration(hours: 4)),
        canBook: true,
      ),
    ],
  );
  @override
  Future<void> addSpace(String b, String l, String level, String notes) async =>
      throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> publish(String id, DateTime start, DateTime end) async =>
      throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> book(String id) async => throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> cancel(String id) async => throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> updateSpace(String id, String l, String level, String n) async =>
      throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> removeSpace(String id) async =>
      throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<void> publishSeries(String id, List<ParkingWindow> windows) async =>
      throw StateError('תצוגת עיצוב בלבד');
  @override
  Future<List<ParkingOffer>> history(String buildingId) async => const [];
}

/// One weekday in the "which days" row: a full-height toggle that screen
/// readers announce by the day's full name.
class _DayToggle extends StatelessWidget {
  const _DayToggle({
    super.key,
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });
  final String letter, name;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    return Semantics(
      button: true,
      selected: selected,
      label: 'יום $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? t.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(Corners.chip),
            border: Border.all(color: selected ? t.accent : t.rule),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? t.onAccent : t.ink,
            ),
          ),
        ),
      ),
    );
  }
}
