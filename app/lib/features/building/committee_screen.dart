import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/building/committee_repository.dart';
import 'committee_inquiries.dart';
import 'glass_widgets.dart';

const _months = [
  'ינואר',
  'פברואר',
  'מרץ',
  'אפריל',
  'מאי',
  'יוני',
  'יולי',
  'אוגוסט',
  'ספטמבר',
  'אוקטובר',
  'נובמבר',
  'דצמבר',
];
const _weekdays = ['ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'שבת', 'א׳'];

/// "יום ג׳ 15.12", or "שבת 19.12".
String committeeDate(DateTime d) {
  final day = _weekdays[d.weekday - 1];
  return '${day == 'שבת' ? day : 'יום $day'} ${d.day}.${d.month}';
}

/// The name residents see for a charge: a monthly fee carries its month.
String committeeTitle(CommitteeCharge c) => c.monthly && c.period != null
    ? '${c.title} · ${_months[c.period!.month - 1]}'
    : c.title;

String shekels(int amount) => '\u2066$amount ₪\u2069';

const _methods = {'bit': 'bit', 'paybox': 'PayBox', 'cash': 'מזומן'};

class CommitteeScreen extends StatefulWidget {
  const CommitteeScreen({
    super.key,
    required this.repository,
    required this.buildingId,
    required this.apartment,
    this.openLink,
  });
  final CommitteeRepository repository;
  final String buildingId, apartment;

  /// Opens a payment link; replaceable in tests.
  final Future<bool> Function(Uri uri)? openLink;
  @override
  State<CommitteeScreen> createState() => _CommitteeScreenState();
}

class _CommitteeScreenState extends State<CommitteeScreen> {
  late final model = CommitteeViewModel(widget.repository, widget.buildingId)
    ..load();

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(String link) async {
    final uri = Uri.tryParse(link);
    var ok = false;
    if (uri != null) {
      try {
        ok =
            await (widget.openLink ??
                (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
      } catch (_) {}
    }
    if (!ok && mounted) _message('לא הצלחנו לפתוח את קישור התשלום.');
  }

  Future<void> _reportPaid(CommitteeCharge c) async {
    final settings = model.snapshot.settings;
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('איך שילמת?'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'הוועד יקבל עדכון ויאשר את התשלום של ${committeeTitle(c)}.',
              style: TextStyle(color: ctx.glass.muted),
            ),
          ),
          for (final m in _methods.entries)
            if (m.key == 'cash' ||
                (m.key == 'bit' && settings.bitLink.isNotEmpty) ||
                (m.key == 'paybox' && settings.payboxLink.isNotEmpty) ||
                !settings.canPayInApp)
              SimpleDialogOption(
                key: ValueKey('committee-method-${m.key}'),
                onPressed: () => Navigator.pop(ctx, m.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(m.value, style: const TextStyle(fontSize: 16)),
                ),
              ),
        ],
      ),
    );
    if (method == null || !mounted) return;
    final ok = await model.run(
      () => widget.repository.reportPaid(c.id, method),
    );
    if (mounted) {
      _message(ok ? 'תודה! הוועד יאשר את התשלום.' : model.error ?? 'לא נשמר');
    }
  }

  Future<void> _sheet(Widget Function(BuildContext) builder) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 640),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: builder(ctx),
        ),
      );

  Future<void> _addCharge() => _sheet(
    (ctx) => ChargeEditor(
      onSave: (title, notes, amount, due) => model.run(
        () => widget.repository.addCharge(
          widget.buildingId,
          title: title,
          notes: notes,
          amount: amount,
          dueOn: due,
        ),
      ),
      error: () => model.error,
    ),
  );

  Future<void> _settings() => _sheet(
    (ctx) => CommitteeSettingsEditor(
      model: model,
      onSave: (s) =>
          model.run(() => widget.repository.saveSettings(widget.buildingId, s)),
      onMember: (m, on) =>
          model.run(() => widget.repository.setMember(m.id, on)),
    ),
  );

  Future<void> _payments(CommitteeCharge c) => _sheet(
    (ctx) => ChargePayments(
      model: model,
      chargeId: c.id,
      onMark: (a, paid) => model.run(
        () => widget.repository.markPaid(c.id, a.apartmentId, paid),
      ),
      onCancel: () async {
        final sure = await showDialog<bool>(
          context: ctx,
          builder: (d) => AlertDialog(
            title: Text('לבטל את ${committeeTitle(c)}?'),
            content: const Text(
              'החיוב ייעלם מהדף של כל הדיירים. תשלומים שכבר סומנו נשמרים ברישום.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('חזרה'),
              ),
              FilledButton(
                key: const Key('committee-cancel-confirm'),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('ביטול החיוב'),
              ),
            ],
          ),
        );
        if (sure != true) return;
        final ok = await model.run(() => widget.repository.cancelCharge(c.id));
        if (ok && ctx.mounted) Navigator.pop(ctx);
        if (mounted) _message(ok ? 'החיוב בוטל' : model.error ?? 'לא בוטל');
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final s = model.snapshot;
      final open = s.charges.where((c) => !c.settled).toList()
        ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
      final settled = s.charges.where((c) => c.settled).toList();
      return RefreshIndicator(
        onRefresh: model.load,
        child: ListView(
          key: const Key('committee-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            const Eyebrow('הבית שלנו, בניהול משותף'),
            const SizedBox(height: Space.xs),
            Text('ועד הבית', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              s.committee.isEmpty
                  ? 'כל התשלומים של הבניין, במקום אחד.'
                  : 'הוועד: ${s.committee.join(', ')}',
              style: TextStyle(color: context.glass.muted),
            ),
            if (s.isCommittee) ...[
              const SizedBox(height: Space.l),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('committee-add'),
                      onPressed: model.saving ? null : _addCharge,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('חיוב חדש'),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('committee-settings'),
                      onPressed: model.saving ? null : _settings,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('דמי ועד ותשלום'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.l),
            InquiriesEntry(
              repository: widget.repository.inquiries,
              buildingId: widget.buildingId,
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
                child: StateMessage(
                  icon: Icons.error_outline_rounded,
                  title: model.error!,
                  error: true,
                  action: TextButton(
                    onPressed: model.loading || model.saving
                        ? null
                        : model.load,
                    child: const Text('ניסיון נוסף'),
                  ),
                ),
              ),
            if (!model.loaded && model.loading)
              const LoadingState(label: 'טוענים את דף הוועד…')
            else if (model.error == null && s.charges.isEmpty)
              StateMessage(
                icon: Icons.account_balance_wallet_outlined,
                title: s.isCommittee
                    ? 'מתחילים בדמי הוועד'
                    : 'אין כרגע תשלומים לוועד',
                text: s.isCommittee
                    ? 'קובעים סכום חודשי ומדביקים קישור bit או PayBox. כל חודש ייפתח חיוב חדש לבד, וכל דייר יוכל לשלם בלחיצה.'
                    : 'כשהוועד יפתח חיוב, למשל דמי ועד או תיקון, הוא יופיע כאן עם כפתור תשלום.',
              )
            else ...[
              if (open.isNotEmpty) const SectionTitle('לתשלום'),
              for (final c in open)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _chargeCard(c),
                ),
              if (settled.isNotEmpty) ...[
                const SizedBox(height: Space.s),
                const SectionTitle('שולם'),
                for (final c in settled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _settledRow(c),
                  ),
              ],
            ],
          ],
        ),
      );
    },
  );

  Widget _chargeCard(CommitteeCharge c) {
    final t = context.glass;
    final s = model.snapshot.settings;
    final today = DateUtils.dateOnly(DateTime.now());
    final late = c.dueOn.isBefore(today) && c.myStatus.isEmpty;
    final reported = c.myStatus == 'reported';
    return GlassPanel(
      key: ValueKey('committee-charge-${c.id}'),
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      committeeTitle(c),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'לתשלום עד ${committeeDate(c.dueOn)}',
                      style: TextStyle(color: late ? t.error : t.muted),
                    ),
                  ],
                ),
              ),
              Text(
                shekels(c.amount),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            Text(c.notes),
          ],
          const SizedBox(height: Space.m),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (reported)
                const SoftTag(
                  'ממתין לאישור הוועד',
                  icon: Icons.hourglass_top_rounded,
                )
              else if (late)
                SoftTag(
                  'עבר מועד התשלום',
                  color: t.error,
                  icon: Icons.schedule_rounded,
                ),
              if (c.households > 0)
                SoftTag(
                  '${c.paid} מתוך ${c.households} דירות שילמו',
                  color: t.muted,
                  icon: Icons.groups_2_outlined,
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          if (!reported) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.bitLink.isNotEmpty)
                  FilledButton(
                    key: ValueKey('committee-bit-${c.id}'),
                    onPressed: () => _open(s.bitLink),
                    child: const Text('תשלום ב־bit'),
                  ),
                if (s.payboxLink.isNotEmpty)
                  OutlinedButton(
                    key: ValueKey('committee-paybox-${c.id}'),
                    onPressed: () => _open(s.payboxLink),
                    child: const Text('תשלום ב־PayBox'),
                  ),
                TextButton.icon(
                  key: ValueKey('committee-paid-${c.id}'),
                  onPressed: model.saving ? null : () => _reportPaid(c),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('שילמתי'),
                ),
              ],
            ),
            if (!s.canPayInApp || s.cashNote.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Text(
                  [
                    if (!s.canPayInApp) 'אפשר לשלם לוועד במזומן.',
                    if (s.cashNote.isNotEmpty) 'מזומן: ${s.cashNote}',
                  ].join(' '),
                  style: TextStyle(color: t.muted, fontSize: 13),
                ),
              ),
          ],
          if (model.snapshot.isCommittee)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('committee-payments-${c.id}'),
                onPressed: model.saving ? null : () => _payments(c),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  'מי שילם${_waiting(c) > 0 ? ' · ${_waiting(c)} ממתינים לאישור' : ''}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _waiting(CommitteeCharge c) =>
      c.apartments.where((a) => a.status == 'reported').length;

  Widget _settledRow(CommitteeCharge c) => GlassPanel(
    key: ValueKey('committee-settled-${c.id}'),
    faded: true,
    padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: 12),
    child: Row(
      children: [
        Icon(Icons.check_circle_rounded, color: context.glass.accent),
        const SizedBox(width: Space.s),
        Expanded(child: Text(committeeTitle(c))),
        Text(shekels(c.amount)),
        if (model.snapshot.isCommittee)
          IconButton(
            tooltip: 'מי שילם',
            onPressed: model.saving ? null : () => _payments(c),
            icon: const Icon(Icons.fact_check_outlined),
          ),
      ],
    ),
  );
}

/// The committee's form for a one-off charge, such as a repair.
class ChargeEditor extends StatefulWidget {
  const ChargeEditor({super.key, required this.onSave, required this.error});
  final Future<bool> Function(
    String title,
    String notes,
    int amount,
    DateTime due,
  )
  onSave;
  final String? Function() error;
  @override
  State<ChargeEditor> createState() => _ChargeEditorState();
}

class _ChargeEditorState extends State<ChargeEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      amount = TextEditingController(),
      notes = TextEditingController();
  DateTime due = DateUtils.dateOnly(DateTime.now())
      .add(const Duration(days: 14));
  bool saving = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: due,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => due = picked);
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.onSave(
      title.text.trim(),
      notes.text.trim(),
      int.parse(amount.text.trim()),
      due,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('החיוב פורסם לדיירים')));
    } else {
      setState(() {
        saving = false;
        error = widget.error();
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
            Text('חיוב חדש', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              'למשל תיקון דלת הכניסה. כל דירה תראה את החיוב עם כפתור תשלום.',
              style: TextStyle(color: context.glass.muted),
            ),
            const SizedBox(height: Space.xxl),
            TextFormField(
              key: const Key('charge-title'),
              controller: title,
              enabled: !saving,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'על מה משלמים?',
                hintText: 'למשל תיקון דלת הכניסה',
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'יש לכתוב על מה החיוב' : null,
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              key: const Key('charge-amount'),
              controller: amount,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'סכום לכל דירה',
                suffixText: '₪',
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 1 || n > 100000
                    ? 'יש להזין סכום בשקלים'
                    : null;
              },
            ),
            const SizedBox(height: Space.m),
            OutlinedButton.icon(
              key: const Key('charge-due'),
              onPressed: saving ? null : _pickDue,
              icon: const Icon(Icons.event_outlined),
              label: Text('לתשלום עד ${committeeDate(due)}'),
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              key: const Key('charge-notes'),
              controller: notes,
              enabled: !saving,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'פרטים לדיירים (לא חובה)',
                hintText: 'למשל: הצעת מחיר של המנעולן, אפשר לשלם גם במזומן',
              ),
            ),
            if (int.tryParse(amount.text.trim()) case final n? when n > 0) ...[
              const SizedBox(height: Space.s),
              GlassPanel(
                tone: GlassTone.accent,
                padding: const EdgeInsets.all(Space.l),
                child: Text(
                  'כל דירה תשלם ${shekels(n)} עד ${committeeDate(due)}.',
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
              key: const Key('charge-save'),
              onPressed: saving ? null : _save,
              child: Text(saving ? 'שומרים…' : 'פרסום החיוב'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Monthly fee, payment links and committee members.
class CommitteeSettingsEditor extends StatefulWidget {
  const CommitteeSettingsEditor({
    super.key,
    required this.model,
    required this.onSave,
    required this.onMember,
  });
  final CommitteeViewModel model;
  final Future<bool> Function(CommitteeSettings settings) onSave;
  final Future<bool> Function(CommitteeMember member, bool on) onMember;
  @override
  State<CommitteeSettingsEditor> createState() =>
      _CommitteeSettingsEditorState();
}

class _CommitteeSettingsEditorState extends State<CommitteeSettingsEditor> {
  final form = GlobalKey<FormState>();
  late final s = widget.model.snapshot.settings;
  late final amount = TextEditingController(
        text: s.monthlyAmount == 0 ? '' : '${s.monthlyAmount}',
      ),
      bit = TextEditingController(text: s.bitLink),
      paybox = TextEditingController(text: s.payboxLink),
      cash = TextEditingController(text: s.cashNote);
  late int day = s.monthlyDueDay;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    bit.dispose();
    paybox.dispose();
    cash.dispose();
    super.dispose();
  }

  static String? _link(String? v, String name) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null;
    return text.startsWith('https://') && !text.contains(' ')
        ? null
        : 'יש להדביק את קישור $name המלא, שמתחיל ב־https://';
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    final ok = await widget.onSave(
      CommitteeSettings(
        monthlyAmount: int.tryParse(amount.text.trim()) ?? 0,
        monthlyDueDay: day,
        bitLink: bit.text.trim(),
        payboxLink: paybox.text.trim(),
        cashNote: cash.text.trim(),
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ההגדרות נשמרו')));
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
              'דמי ועד ותשלום',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.xxl),
            Text(
              'דמי ועד חודשיים',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.s),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('committee-monthly'),
                    controller: amount,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'סכום לדירה',
                      hintText: 'ריק = בלי',
                      suffixText: '₪',
                    ),
                    validator: (v) =>
                        (int.tryParse(v?.trim() ?? '') ?? 0) > 100000
                        ? 'סכום גבוה מדי'
                        : null,
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('committee-due-day'),
                    initialValue: day,
                    decoration: const InputDecoration(
                      labelText: 'עד יום בחודש',
                    ),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() => day = v ?? day),
                  ),
                ),
              ],
            ),
            Text(
              'בכל חודש ייפתח לבד חיוב של דמי ועד לכל דירה.',
              style: TextStyle(color: context.glass.muted, fontSize: 13),
            ),
            const SizedBox(height: Space.xl),
            Text(
              'איך משלמים לוועד',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Space.s),
            TextFormField(
              key: const Key('committee-bit'),
              controller: bit,
              enabled: !saving,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'קישור לתשלום ב־bit (לא חובה)',
              ),
              validator: (v) => _link(v, 'bit'),
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              key: const Key('committee-paybox'),
              controller: paybox,
              enabled: !saving,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'קישור לקבוצת PayBox (לא חובה)',
              ),
              validator: (v) => _link(v, 'PayBox'),
            ),
            const SizedBox(height: Space.m),
            TextFormField(
              key: const Key('committee-cash'),
              controller: cash,
              enabled: !saving,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'מזומן: למי מוסרים? (לא חובה)',
                hintText: 'למשל: לרונית מדירה 4',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: context.glass.error),
                ),
              ),
            const SizedBox(height: Space.l),
            FilledButton(
              key: const Key('committee-settings-save'),
              onPressed: saving ? null : _save,
              child: Text(saving ? 'שומרים…' : 'שמירה'),
            ),
            const SizedBox(height: Space.xxl),
            Text('חברי הוועד', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'מנהלי הבניין תמיד בוועד. אפשר לצרף עוד שכנים.',
              style: TextStyle(color: context.glass.muted, fontSize: 13),
            ),
            ListenableBuilder(
              listenable: widget.model,
              builder: (context, _) => Column(
                children: [
                  for (final m in widget.model.snapshot.members)
                    CheckboxListTile(
                      key: ValueKey('committee-member-${m.id}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(m.name),
                      subtitle: Text(
                        'דירה ${m.apartment}${m.isAdmin ? ' · מנהל/ת הבניין' : ''}',
                      ),
                      value: m.onCommittee,
                      onChanged: m.isAdmin || widget.model.saving
                          ? null
                          : (on) => widget.onMember(m, on ?? false),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The committee's view of who paid one charge.
class ChargePayments extends StatelessWidget {
  const ChargePayments({
    super.key,
    required this.model,
    required this.chargeId,
    required this.onMark,
    required this.onCancel,
  });
  final CommitteeViewModel model;
  final String chargeId;
  final Future<bool> Function(CommitteeApartment apartment, bool paid) onMark;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final c = model.snapshot.charges
          .where((c) => c.id == chargeId)
          .firstOrNull;
      if (c == null) return const SizedBox(height: 120);
      final t = context.glass;
      final waiting = c.apartments.where((a) => a.status == 'reported');
      final rest = c.apartments.where((a) => a.status != 'reported');
      Widget row(CommitteeApartment a) => CheckboxListTile(
        key: ValueKey('committee-apartment-${a.apartmentId}'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text('דירה ${a.apartment}'),
        subtitle: Text(
          switch (a.status) {
            'confirmed' => 'שולם${_methodName(a.method)}',
            'reported' => 'הדייר סימן ששילם${_methodName(a.method)}. מאשרים?',
            _ => 'עוד לא שולם',
          },
          style: TextStyle(color: a.status == 'reported' ? t.accent : t.muted),
        ),
        value: a.status == 'confirmed',
        onChanged: model.saving ? null : (v) => onMark(a, v ?? false),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              committeeTitle(c),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: Space.s),
            Text(
              '${shekels(c.amount)} לדירה · ${c.paid} מתוך ${c.households} שילמו',
              style: TextStyle(color: t.muted),
            ),
            const SizedBox(height: Space.s),
            Text(
              'רק הוועד רואה את הרשימה הזאת. הדיירים רואים רק את המספר הכולל.',
              style: TextStyle(color: t.muted, fontSize: 13),
            ),
            if (model.saving) const LinearProgressIndicator(minHeight: 2),
            if (waiting.isNotEmpty) ...[
              const SizedBox(height: Space.l),
              const SectionTitle('ממתינים לאישור'),
              for (final a in waiting) row(a),
            ],
            const SizedBox(height: Space.l),
            const SectionTitle('כל הדירות'),
            for (final a in rest) row(a),
            const SizedBox(height: Space.xl),
            TextButton.icon(
              key: const Key('committee-cancel'),
              onPressed: model.saving ? null : onCancel,
              icon: Icon(Icons.delete_outline_rounded, color: t.error),
              label: Text('ביטול החיוב', style: TextStyle(color: t.error)),
            ),
          ],
        ),
      );
    },
  );

  static String _methodName(String m) =>
      _methods[m] == null ? '' : ' ב־${_methods[m]}';
}
