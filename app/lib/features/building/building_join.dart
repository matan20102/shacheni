part of 'building_app.dart';

// Joining a building, join requests and approvals, and the updates sheet.
extension _JoinRequests on _BuildingExperienceState {
  void _join({String? code}) => _sheet(
    (ctx) => _JoinForm(
      repository: vm.repository,
      initialCode: code,
      onApply: (home, apartment, floor, householdName) async {
        await vm.run(() async {
          await vm.repository.apply(
            home,
            apartment,
            floor: floor,
            householdName: householdName,
          );
        }, refresh: false); // apply() already reloads the application state.
        if (!ctx.mounted || !mounted) return;
        Navigator.pop(ctx);
        _message('הבקשה נשלחה. נעדכן אותך כשההצטרפות תאושר.');
      },
    ),
  );

  void _applications() {
    final updates = <ApprovalUpdate>[];
    final queuedReadIds = <String>{};
    final notes = <BuildingUpdate>[];
    final queuedNoteIds = <String>{};
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
            // Updates stay on screen while the sheet is open, and are marked
            // read once, the same way accepted requests are.
            for (final note in vm.updates) {
              if (!notes.any((shown) => shown.id == note.id)) notes.add(note);
            }
            final unreadNotes = vm.updates
                .where((note) => !queuedNoteIds.contains(note.id))
                .map((note) => note.id)
                .toList();
            if (unreadNotes.isNotEmpty) {
              queuedNoteIds.addAll(unreadNotes);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!ctx.mounted) return;
                unawaited(
                  _perform(() => vm.repository.readUpdates(unreadNotes)),
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
                  Text(
                    'הגישה לתוכן הבניין נפתחת רק אחרי האישורים הנדרשים.',
                    style: TextStyle(color: context.glass.muted),
                  ),
                  const SizedBox(height: 20),
                  if (updates.isEmpty &&
                      notes.isEmpty &&
                      vm.pending.isEmpty &&
                      vm.inbox.isEmpty)
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
                  for (final note in notes) ...[
                    GlassPanel(
                      key: ValueKey('building-update-${note.id}'),
                      child: Builder(
                        builder: (_) {
                          final view = _updateText(note);
                          return _FeatureLine(view.icon, view.title, view.body);
                        },
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
                                  ? 'אישור הצטרפות לבניין'
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
                                  ? 'אישור הצטרפות לדירה'
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
                      )
                    else if (application.canApproveBuilding ||
                        application.canApproveApartment)
                      TextButton(
                        key: ValueKey('application-reject-${application.id}'),
                        onPressed: vm.busy ? null : () => _reject(application),
                        child: const Text('דחיית הבקשה'),
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.glass.accent,
            ),
          ),
        Text(
          'דירה ${a.apartment}',
          style: TextStyle(color: context.glass.muted),
        ),
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
            style: TextStyle(fontSize: 12, color: context.glass.muted),
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
        color: approved ? context.glass.accent : context.glass.muted,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(
        approved ? 'אושר' : 'ממתין לאישור',
        style: TextStyle(
          color: approved ? context.glass.accent : context.glass.muted,
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

  Future<void> _reject(JoinApplication a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('לדחות את הבקשה של ${a.applicantName}?'),
        content: const Text(
          'המבקש יקבל עדכון שהבקשה לא אושרה, ויוכל לשלוח בקשה חדשה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('application-reject-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('דחיית הבקשה'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(() => vm.repository.reject(a.id));
  }

  ({IconData icon, String title, String body}) _updateText(BuildingUpdate u) {
    final when = u.startsAt == null ? '' : ' · ${parkingTime(u.startsAt!)}';
    final quote = u.text.isEmpty ? '' : '\n״${u.text}״';
    return switch (u.type) {
      'community.application_rejected' => (
        icon: Icons.info_outline_rounded,
        title: 'הבקשה לא אושרה',
        body:
            'בקשת ההצטרפות ל${u.buildingName} לא אושרה. אפשר לבדוק את הפרטים ולשלוח בקשה חדשה.',
      ),
      'community.member_removed' => (
        icon: Icons.info_outline_rounded,
        title: 'החברות בבניין הסתיימה',
        body: 'מנהל הבניין הסיר את החברות שלך ב${u.buildingName}.',
      ),
      'board.reply' => (
        icon: Icons.chat_bubble_outline_rounded,
        title: 'תגובה חדשה לפרסום שלך',
        body: '${u.buildingName}$quote',
      ),
      'board.report' => (
        icon: Icons.flag_outlined,
        title: 'דיווח על תוכן בלוח',
        body:
            '${u.buildingName}$quote\nאפשר לטפל בדיווח ממסך מידע וניהול הבניין.',
      ),
      'parking.booked' => (
        icon: Icons.local_parking_rounded,
        title: 'החניה שלכם הוזמנה',
        body: 'חניה ${u.text}$when · ${u.buildingName}',
      ),
      'parking.booking_cancelled' => (
        icon: Icons.local_parking_rounded,
        title: 'הזמנת חניה בוטלה',
        body: 'חניה ${u.text}$when חזרה להיות פנויה לשכנים.',
      ),
      'parking.offer_cancelled' => (
        icon: Icons.local_parking_rounded,
        title: 'שיתוף החניה בוטל',
        body: 'חניה ${u.text}$when כבר אינה שמורה לך.',
      ),
      _ => (
        icon: Icons.notifications_none_rounded,
        title: 'עדכון חדש',
        body: u.buildingName,
      ),
    };
  }
}

class _JoinForm extends StatefulWidget {
  const _JoinForm({
    required this.repository,
    required this.onApply,
    this.initialCode,
  });
  final String? initialCode;
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
  void initState() {
    super.initState();
    final invited = widget.initialCode;
    if (invited == null) return;
    code.text = invited;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkCode();
    });
  }

  void _checkCode() {
    if (submitting) return;
    if (code.text.trim().isEmpty) {
      setState(() => error = 'יש להזין את קוד הבניין');
      return;
    }
    submit(() async {
      final result = await widget.repository.resolveCode(code.text);
      if (!mounted) return;
      setState(() {
        _resetApartment();
        found = result;
        error = found == null ? 'לא נמצא בניין עם הקוד הזה' : null;
      });
      _queueApartmentCheck();
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
          Text(
            'מזינים את הקוד שקיבלת ממנהל הבניין.',
            style: TextStyle(color: context.glass.muted),
          ),
          const SizedBox(height: 22),
          TextField(
            key: const Key('join-code'),
            controller: code,
            enabled: !submitting,
            textDirection: TextDirection.ltr,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _checkCode(),
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
            Text(
              'קוד לבדיקה: NEIGHBOR. בדירות 1, 2 ו־12 יש מנהל דירה.',
              style: TextStyle(fontSize: 12, color: context.glass.muted),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: submitting ? null : _checkCode,
            child: const Text('בדיקת הקוד'),
          ),
          if (submitError != null)
            Text(submitError!, style: TextStyle(color: context.glass.error)),
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
              Text(
                'בודקים את הדירה…',
                style: TextStyle(color: context.glass.muted),
              ),
            if (lookupError != null) ...[
              Text(lookupError!, style: TextStyle(color: context.glass.error)),
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
