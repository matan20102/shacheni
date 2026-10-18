import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../data/building/parking_repository.dart';
import 'glass_widgets.dart';

String parkingTime(DateTime date) =>
    '\u2066${date.day}.${date.month} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}\u2069';

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
  Future<void> _editor([ParkingSpace? space]) async {
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
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => section = 1);
      _message(space == null ? 'החניה נוספה לדירה' : 'הזמינות פורסמה לשכנים');
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
            const SizedBox(height: 12),
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
              _ => o.myBooking,
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
            const SizedBox(height: 4),
            Text(
              'החניון שלנו',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'חניה פנויה אצלך? לשכן זה יכול לעשות את היום.',
              style: TextStyle(color: glassMuted),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('parking-add'),
                onPressed: model.saving ? null : () => _editor(),
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('הוספת חניה לדירה'),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    key: ValueKey('parking-section-$i'),
                    selected: section == i,
                    onSelected: (_) => setState(() => section = i),
                    label: Text(['פנויות', 'החניות שלנו', 'ההזמנות שלי'][i]),
                  ),
              ],
            ),
            const SizedBox(height: 18),
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: ValueKey('parking-share-${space.id}'),
                          onPressed: model.saving ? null : () => _editor(space),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('שיתוף זמן פנוי'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (offers.isNotEmpty) const SectionTitle('הזמנים ששיתפנו'),
            ],
            for (final offer in offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _offerCard(offer),
              ),
            if (!model.loading &&
                model.error == null &&
                offers.isEmpty &&
                (section != 1 || model.snapshot.spaces.isEmpty))
              GlassPanel(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.local_parking_rounded,
                      color: glassTeal,
                      size: 34,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      [
                        'עדיין אין חניות פנויות',
                        'החניות של הבית, במקום אחד',
                        'עוד אין לך הזמנות',
                      ][section],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        'כששכן ישתף חניה, אפשר יהיה להזמין אותה כאן.',
                        'מוסיפים חניה פעם אחת. כל בני הבית יוכלו לשתף אותה כשהיא פנויה.',
                        'חניה שהזמנת תופיע כאן עם השעות והמיקום.',
                      ][section],
                      style: const TextStyle(color: glassMuted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _spaceTitle(ParkingSpace space, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFD9EFED),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.local_parking_rounded, color: glassTeal),
      ),
      const SizedBox(width: 12),
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
              style: const TextStyle(fontSize: 12, color: glassMuted),
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
        const SizedBox(height: 14),
        Text(
          'מ־${parkingTime(o.startsAt)}\nעד ${parkingTime(o.endsAt)}',
          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.7),
        ),
        if (o.space.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              o.space.notes,
              style: const TextStyle(color: glassMuted),
            ),
          ),
        const SizedBox(height: 12),
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
  });
  final ParkingViewModel model;
  final String apartment;
  final ParkingSpace? space;
  @override
  State<ParkingEditor> createState() => _ParkingEditorState();
}

class _ParkingEditorState extends State<ParkingEditor> {
  final form = GlobalKey<FormState>();
  final label = TextEditingController(),
      level = TextEditingController(),
      notes = TextEditingController();
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
        start = picked;
      } else {
        end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    if (widget.space != null &&
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
          : widget.model.repository.publish(widget.space!.id, start, end),
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
                  : 'משתפים את חניה ${widget.space!.label}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.space == null
                  ? 'החניה תשויך לדירה ${widget.apartment}. כל בני הבית יוכלו לנהל את השיתוף.'
                  : 'השכנים יוכלו להזמין בחינם את כל הטווח שפרסמת, ללא אישור נוסף.',
              style: const TextStyle(color: glassMuted),
            ),
            const SizedBox(height: 22),
            if (widget.space == null) ...[
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
              OutlinedButton.icon(
                key: const Key('parking-start'),
                onPressed: saving ? null : () => _pick(true),
                icon: const Icon(Icons.event_available_outlined),
                label: Text('פנויה מ־${parkingTime(start)}'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('parking-end'),
                onPressed: saving ? null : () => _pick(false),
                icon: const Icon(Icons.schedule_rounded),
                label: Text('עד ${parkingTime(end)}'),
              ),
              const SizedBox(height: 12),
              const SoftTag(
                'שיתוף בחינם · הזמנה לכל הטווח',
                icon: Icons.favorite_border_rounded,
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFAB3D3D)),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('parking-save'),
              onPressed: saving ? null : _save,
              child: Text(
                saving
                    ? 'שומרים…'
                    : widget.space == null
                    ? 'הוספת החניה'
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
}
