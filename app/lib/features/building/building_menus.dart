part of 'building_app.dart';

// Building picker, profile, building info and lifecycle actions, creation.
extension _BuildingMenus on _BuildingExperienceState {
  void _chooseBuilding() => _sheet(
    (ctx) => ListenableBuilder(
      listenable: vm,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('הבניינים שלי', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              'בוחרים בית, ומקבלים רק את מה ששייך אליו.',
              style: TextStyle(color: context.glass.muted),
            ),
            const SizedBox(height: Space.xl),
            for (final home in vm.homes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.apartment_rounded,
                          color: context.glass.accent,
                        ),
                        title: Text(home.name),
                        subtitle: Text(
                          '${home.address} · ${_apartmentLabel(home)}',
                        ),
                        trailing: home.id == vm.active?.id
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: context.glass.accent,
                              )
                            : null,
                        onTap: () {
                          unawaited(
                            _perform(() => vm.select(home.id), refresh: false),
                          );
                          Navigator.pop(ctx);
                        },
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          key: ValueKey('building-info-${home.id}'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _buildingInfo(home.id);
                          },
                          icon: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('מידע וניהול הבניין'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Space.m),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _create();
              },
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('יצירת בניין חדש'),
            ),
            const SizedBox(height: Space.s),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _join();
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('הצטרפות עם קוד בניין'),
            ),
            if ((vm.active?.code ?? '').isNotEmpty) ...[
              const SectionTitle('מזמינים את השכנים'),
              GlassPanel(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'קוד ההצטרפות לבניין',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.glass.muted,
                            ),
                          ),
                          // The copy button next to it serves screen readers.
                          Semantics(
                            label: 'קוד הבניין ${vm.active!.code}',
                            excludeSemantics: true,
                            child: SelectableText(
                              vm.active!.code,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.glass.accent,
                              ),
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
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('building-invite-copy'),
                    onPressed: () async {
                      final home = vm.active!;
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'הצטרפו ל״${home.name}״ ב$appNameHebrew:\n${inviteLink(home.code)}\nקוד הבניין: ${home.code}',
                        ),
                      );
                      if (mounted) {
                        _message('ההזמנה הועתקה. אפשר להדביק ולשלוח.');
                      }
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('העתקת הזמנה עם קישור'),
                  ),
                  TextButton.icon(
                    key: const Key('building-invite-qr'),
                    onPressed: () => showInvitePoster(
                      context,
                      name: vm.active!.name,
                      code: vm.active!.code,
                    ),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                    label: const Text('קוד QR ללובי'),
                  ),
                  if (vm.active!.isAdmin)
                    TextButton.icon(
                      key: const Key('building-code-rotate'),
                      onPressed: vm.busy ? null : () => _rotateCode(vm.active!),
                      icon: const Icon(Icons.autorenew_rounded, size: 18),
                      label: const Text('החלפת הקוד'),
                    ),
                ],
              ),
              const SizedBox(height: Space.m),
              Text(
                vm.live
                    ? 'הקוד מאפשר בקשת הצטרפות; הגישה נפתחת לאחר אישור.'
                    : 'בתצוגה המקומית הקוד עובד באותה הפעלה בלבד.',
                style: TextStyle(fontSize: 12, color: context.glass.muted),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  void _profile() => _sheet(
    (ctx) => ProfileEditor(
      profile: vm.repository.profile,
      onSave: (name, phone) async {
        await vm.run(() => vm.repository.updateProfile(name, phone));
        if (ctx.mounted) Navigator.pop(ctx);
      },
      onDelete: widget.onSignOut == null ? null : () => _deleteAccount(ctx),
    ),
  );

  void _buildingInfo(String buildingId) {
    _sheet(
      (ctx) => BuildingManagementSheet(
        vm: vm,
        buildingId: buildingId,
        onLeave: (context, home) => _lifecycle(context, home, archive: false),
        onArchive: (context, home) => _lifecycle(context, home, archive: true),
      ),
    );
  }

  void _platformConsole() {
    final repository = vm.repository.platform;
    if (!vm.repository.isPlatformAdmin || repository == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PlatformConsole(repository: repository, onChanged: vm.synchronize),
      ),
    );
  }

  Future<void> _lifecycle(
    BuildContext sheet,
    BuildingHome home, {
    required bool archive,
  }) async {
    final confirmed = await showDialog<bool>(
      context: sheet,
      builder: (ctx) => AlertDialog(
        title: Text(archive ? 'לארכב את הבניין?' : 'לצאת מהבניין?'),
        content: Text(
          archive
              ? 'הפעילות ב־${home.name} תיסגר לכל הדיירים, והצטרפות חדשה תיחסם. המידע וההיסטוריה יישמרו.'
              : 'הגישה שלך ל־${home.name} תיסגר. כדי לחזור תידרש בקשת הצטרפות חדשה ואישור.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('building-lifecycle-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(archive ? 'ארכוב הבניין' : 'יציאה מהבניין'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !sheet.mounted) return;
    try {
      await vm.run(
        () => archive ? vm.repository.archive(home) : vm.repository.leave(home),
      );
    } catch (error) {
      if (!sheet.mounted) return;
      await showDialog<void>(
        context: sheet,
        builder: (ctx) => AlertDialog(
          title: const Text('לא ניתן להשלים את הפעולה'),
          content: Text(buildingErrorMessage(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }
    if (mounted && sheet.mounted) {
      Navigator.pop(sheet);
      vm.navigate(0);
      _message(archive ? 'הבניין הועבר לארכיון' : 'יצאת מהבניין');
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

  Future<void> _rotateCode(BuildingHome home) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('להחליף את קוד ההצטרפות?'),
        content: const Text(
          'הקוד הנוכחי וההזמנות שנשלחו איתו יפסיקו לעבוד. דיירים שכבר הצטרפו לא יושפעו.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('building-code-rotate-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('החלפת הקוד'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await _perform(() => vm.repository.rotateCode(home));
    if (changed && mounted) _message('קוד הבניין הוחלף');
  }

  Future<void> _deleteAccount(BuildContext sheet) async {
    final confirmed = await showDialog<bool>(
      context: sheet,
      builder: (ctx) => AlertDialog(
        title: const Text('למחוק את החשבון?'),
        content: const Text(
          'השם, הטלפון, החברות בבניינים, הפרסומים והתגובות שלך יימחקו. אי אפשר לשחזר את החשבון לאחר המחיקה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('account-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: context.glass.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('מחיקת החשבון'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !sheet.mounted) return;
    try {
      await vm.run(() => vm.repository.deleteAccount(), refresh: false);
    } catch (error) {
      if (!sheet.mounted) return;
      await showDialog<void>(
        context: sheet,
        builder: (ctx) => AlertDialog(
          title: const Text('לא ניתן למחוק את החשבון כעת'),
          content: Text(buildingErrorMessage(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('הבנתי'),
            ),
          ],
        ),
      );
      return;
    }
    if (sheet.mounted) Navigator.pop(sheet);
    // The server already ended every session; this clears the device.
    await _perform(() => widget.onSignOut?.call(), refresh: false);
  }
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
        const SizedBox(height: Space.s),
        Text(
          'שם משותף לבני הבית, למשל משפחת כהן. אפשר להשאיר ריק.',
          style: TextStyle(color: context.glass.muted),
        ),
        const SizedBox(height: Space.xl),
        TextField(
          key: const Key('household-name'),
          controller: name,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'שם הבית'),
        ),
        if (submitError != null)
          Text(submitError!, style: TextStyle(color: context.glass.error)),
        const SizedBox(height: Space.m),
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
          const SizedBox(height: Space.s),
          Text(
            'נעים להכיר, שכנים.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.s),
          Text(
            'כמה פרטים והבניין מוכן. אין צורך להזין מראש את כל הדירות.',
            style: TextStyle(color: context.glass.muted),
          ),
          const SizedBox(height: Space.xxl),
          AddressPicker(onChanged: (value) => address.text = value),
          const SizedBox(height: Space.l),
          _field(
            name,
            'שם הבניין · לא חובה',
            'אם משאירים ריק, תוצג הכתובת',
            required: false,
            maxLength: 100,
            key: const Key('building-name'),
          ),
          const SizedBox(height: Space.l),
          _apartmentField(apartment, key: const Key('building-apartment')),
          const SizedBox(height: Space.l),
          _field(
            householdName,
            'שם הבית שלך · לא חובה',
            'למשל: משפחת כהן',
            required: false,
            maxLength: 60,
            key: const Key('building-household-name'),
          ),
          const SizedBox(height: Space.xxl),
          if (submitError != null)
            Text(submitError!, style: TextStyle(color: context.glass.error)),
          const GlassPanel(
            child: _FeatureLine(
              Icons.verified_user_outlined,
              'אתה המנהל הראשון',
              'תקבל הרשאות מנהל בניין, ועד ומנהל הדירה שלך. בהמשך תוכל לצרף מנהלים נוספים.',
            ),
          ),
          const SizedBox(height: Space.xxl),
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
