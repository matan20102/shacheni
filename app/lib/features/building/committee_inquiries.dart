import 'package:flutter/material.dart';

import '../../data/building/inquiry_repository.dart';
import 'glass_widgets.dart';

/// "היום 14:05", "אתמול 09:30" or "12.11 · 18:00".
String inquiryTime(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  final day = DateUtils.dateOnly(t);
  final today = DateUtils.dateOnly(now);
  final clock =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (day == today) return 'היום \u2066$clock\u2069';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'אתמול \u2066$clock\u2069';
  }
  return '\u2066${t.day}.${t.month} · $clock\u2069';
}

/// The committee page's door to private inquiries, with what is waiting.
class InquiriesEntry extends StatefulWidget {
  const InquiriesEntry({
    super.key,
    required this.repository,
    required this.buildingId,
  });
  final InquiryRepository repository;
  final String buildingId;
  @override
  State<InquiriesEntry> createState() => _InquiriesEntryState();
}

class _InquiriesEntryState extends State<InquiriesEntry> {
  InquiryList? list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await widget.repository.list(widget.buildingId);
      if (mounted) setState(() => list = next);
    } catch (_) {
      /* The screen itself shows errors; the entry stays usable. */
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InquiriesScreen(
          repository: widget.repository,
          buildingId: widget.buildingId,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    final l = list;
    final committee = l?.isCommittee ?? false;
    final open = l?.inbox.where((i) => !i.handled).length ?? 0;
    final unread = l?.unread ?? 0;
    final subtitle = committee
        ? (open == 0
              ? 'אין פניות שמחכות לטיפול.'
              : '$open ${open == 1 ? 'פנייה פתוחה' : 'פניות פתוחות'}')
        : 'שאלה, בקשה או תלונה? רק הוועד יראה אותה.';
    return Semantics(
      button: true,
      label: 'פניות לוועד. $subtitle${unread > 0 ? ' $unread חדשות.' : ''}',
      excludeSemantics: true,
      child: Pressable(
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(Corners.panel),
          child: GlassPanel(
            key: const Key('committee-inquiries'),
            padding: const EdgeInsets.all(Space.l),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(Corners.chip),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        committee ? 'פניות מהדיירים' : 'פנייה פרטית לוועד',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(subtitle, style: TextStyle(color: t.muted)),
                    ],
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: Space.s),
                  _Badge(unread),
                ],
                const SizedBox(width: Space.xs),
                Icon(Icons.chevron_left_rounded, color: t.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('inquiries-unread'),
    constraints: const BoxConstraints(minWidth: 26),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.glass.accent,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$count',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

/// The resident's inquiries, or for the committee every inquiry of the building.
class InquiriesScreen extends StatefulWidget {
  const InquiriesScreen({
    super.key,
    required this.repository,
    required this.buildingId,
  });
  final InquiryRepository repository;
  final String buildingId;
  @override
  State<InquiriesScreen> createState() => _InquiriesScreenState();
}

class _InquiriesScreenState extends State<InquiriesScreen> {
  InquiryList list = const InquiryList();
  bool loading = true, loaded = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final next = await widget.repository.list(widget.buildingId);
      if (!mounted) return;
      setState(() {
        list = next;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = inquiryError(e));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loaded = true;
        });
      }
    }
  }

  Future<void> _compose() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: InquiryComposer(
          onSend: (subject, body) =>
              widget.repository.send(widget.buildingId, subject, body),
        ),
      ),
    );
    if (id == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('הפנייה נשלחה לוועד')));
    await _load();
  }

  Future<void> _openThread(InquirySummary i) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InquiryThreadScreen(repository: widget.repository, inquiryId: i.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final committee = list.isCommittee;
    final items = committee ? list.inbox : list.mine;
    final open = items.where((i) => !i.handled).toList();
    final handled = items.where((i) => i.handled).toList();
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(committee ? 'פניות מהדיירים' : 'פניות לוועד'),
          backgroundColor: Colors.transparent,
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('inquiry-new'),
          onPressed: _compose,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('פנייה חדשה'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            key: const Key('inquiries-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              Text(
                committee
                    ? 'פניות פרטיות שהדיירים שלחו לוועד. רק חברי הוועד רואים אותן, והתשובה נשלחת בשם ״הוועד״.'
                    : 'הפנייה נשלחת רק לוועד, ולא מופיעה בלוח. אפשר להמשיך לכתוב באותה פנייה עד שהעניין נסגר.',
                style: TextStyle(color: context.glass.muted),
              ),
              const SizedBox(height: Space.l),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (error != null)
                StateMessage(
                  icon: Icons.error_outline_rounded,
                  title: error!,
                  error: true,
                  action: TextButton(
                    onPressed: loading ? null : _load,
                    child: const Text('ניסיון נוסף'),
                  ),
                )
              else if (!loaded)
                const LoadingState(label: 'טוענים את הפניות…')
              else if (items.isEmpty)
                StateMessage(
                  icon: Icons.mark_email_read_outlined,
                  title: committee ? 'אין עדיין פניות' : 'עוד לא פנית לוועד',
                  text: committee
                      ? 'כשדייר ישלח פנייה פרטית, היא תופיע כאן.'
                      : 'למשל תקלה בבניין, בקשה, או משהו שלא נעים לכתוב בלוח.',
                )
              else ...[
                if (open.isNotEmpty)
                  SectionTitle(committee ? 'מחכות לטיפול' : 'פתוחות'),
                for (final i in open) _row(i, committee),
                if (handled.isNotEmpty) const SectionTitle('טופלו'),
                for (final i in handled) _row(i, committee),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(InquirySummary i, bool committee) {
    final t = context.glass;
    final who = committee
        ? (i.mine ? 'הפנייה שלך' : '${i.author} · דירה ${i.apartment}')
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Semantics(
        button: true,
        label: [
          i.subject,
          ?who,
          if (i.unread) 'הודעה חדשה',
          if (i.handled) 'טופל',
        ].join('. '),
        excludeSemantics: true,
        child: Pressable(
          child: InkWell(
            onTap: () => _openThread(i),
            borderRadius: BorderRadius.circular(Corners.panel),
            child: GlassPanel(
              key: ValueKey('inquiry-${i.id}'),
              faded: i.handled,
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (i.unread) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: Space.s),
                      ],
                      Expanded(
                        child: Text(
                          i.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: i.unread ? FontWeight.w800 : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Text(
                        inquiryTime(i.updatedAt),
                        style: TextStyle(color: t.muted, fontSize: 13),
                      ),
                    ],
                  ),
                  if (who != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(who, style: TextStyle(color: t.accent, fontSize: 13)),
                  ],
                  const SizedBox(height: Space.xs),
                  Text(
                    i.preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.muted),
                  ),
                  if (i.handled) ...[
                    const SizedBox(height: Space.s),
                    SoftTag(
                      'טופל',
                      color: t.muted,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A new inquiry: a subject and the first message.
class InquiryComposer extends StatefulWidget {
  const InquiryComposer({super.key, required this.onSend});
  final Future<String> Function(String subject, String body) onSend;
  @override
  State<InquiryComposer> createState() => _InquiryComposerState();
}

class _InquiryComposerState extends State<InquiryComposer> {
  final form = GlobalKey<FormState>();
  final subject = TextEditingController(), body = TextEditingController();
  bool sending = false;
  String? error;

  @override
  void dispose() {
    subject.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (sending || !form.currentState!.validate()) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final id = await widget.onSend(subject.text.trim(), body.text.trim());
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = inquiryError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'פנייה פרטית לוועד',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Space.xs),
            Text(
              'רק חברי הוועד יראו את הפנייה. השכנים לא רואים אותה.',
              style: TextStyle(color: context.glass.muted),
            ),
            const SizedBox(height: Space.l),
            TextFormField(
              key: const Key('inquiry-subject'),
              controller: subject,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'נושא',
                hintText: 'למשל: נזילה בחדר המדרגות',
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'יש לכתוב נושא' : null,
            ),
            const SizedBox(height: Space.s),
            TextFormField(
              key: const Key('inquiry-body'),
              controller: body,
              maxLength: 2000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'ההודעה',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'יש לכתוב הודעה' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: Space.s),
              Text(error!, style: TextStyle(color: context.glass.error)),
            ],
            const SizedBox(height: Space.l),
            FilledButton.icon(
              key: const Key('inquiry-send'),
              onPressed: sending ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: Text(sending ? 'שולחים…' : 'שליחה לוועד'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One inquiry: the conversation, a reply box, and for the committee "טופל".
class InquiryThreadScreen extends StatefulWidget {
  const InquiryThreadScreen({
    super.key,
    required this.repository,
    required this.inquiryId,
  });
  final InquiryRepository repository;
  final String inquiryId;
  @override
  State<InquiryThreadScreen> createState() => _InquiryThreadScreenState();
}

class _InquiryThreadScreenState extends State<InquiryThreadScreen> {
  InquiryThread? thread;
  final reply = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final next = await widget.repository.open(widget.inquiryId);
      if (mounted) {
        setState(() {
          thread = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = inquiryError(e));
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) setState(() => error = inquiryError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    final text = reply.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      await widget.repository.reply(widget.inquiryId, text);
      reply.clear();
    }, 'ההודעה נשלחה');
  }

  @override
  Widget build(BuildContext context) {
    final th = thread;
    final t = context.glass;
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(th?.subject ?? 'פנייה לוועד'),
          backgroundColor: Colors.transparent,
        ),
        body: th == null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: error != null
                    ? StateMessage(
                        icon: Icons.error_outline_rounded,
                        title: error!,
                        error: true,
                        action: TextButton(
                          onPressed: _load,
                          child: const Text('ניסיון נוסף'),
                        ),
                      )
                    : const LoadingState(label: 'טוענים את הפנייה…'),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      key: const Key('inquiry-messages'),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (th.asCommittee)
                              SoftTag(
                                '${th.author} · דירה ${th.apartment}',
                                icon: Icons.person_outline_rounded,
                              ),
                            th.handled
                                ? SoftTag(
                                    'טופל',
                                    color: t.muted,
                                    icon: Icons.check_circle_outline_rounded,
                                  )
                                : const SoftTag(
                                    'פתוחה',
                                    icon: Icons.mark_email_unread_outlined,
                                  ),
                          ],
                        ),
                        if (!th.asCommittee) ...[
                          const SizedBox(height: Space.s),
                          Text(
                            'רק הוועד רואה את השיחה הזו.',
                            style: TextStyle(color: t.muted, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: Space.l),
                        for (final m in th.messages) _bubble(m),
                        if (th.asCommittee)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: const Key('inquiry-handled'),
                              onPressed: busy
                                  ? null
                                  : () => _run(
                                      () => widget.repository.setHandled(
                                        th.id,
                                        !th.handled,
                                      ),
                                      th.handled
                                          ? 'הפנייה נפתחה מחדש'
                                          : 'הפנייה סומנה כטופלה',
                                    ),
                              icon: Icon(
                                th.handled
                                    ? Icons.undo_rounded
                                    : Icons.check_circle_outline_rounded,
                              ),
                              label: Text(
                                th.handled ? 'פתיחה מחדש' : 'סימון ״טופל״',
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: Space.s),
                            child: Text(
                              error!,
                              style: TextStyle(color: t.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: GlassPanel(
                        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                        radius: Corners.control,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('inquiry-reply'),
                                controller: reply,
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 2000,
                                decoration: InputDecoration(
                                  hintText: th.asCommittee
                                      ? 'תשובה בשם הוועד…'
                                      : (th.handled
                                            ? 'כתיבה תפתח את הפנייה מחדש…'
                                            : 'הוספת הודעה…'),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  counterText: '',
                                ),
                              ),
                            ),
                            IconButton(
                              key: const Key('inquiry-reply-send'),
                              tooltip: 'שליחה',
                              onPressed: busy ? null : _send,
                              icon: Icon(Icons.send_rounded, color: t.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _bubble(InquiryMessage m) {
    final t = context.glass;
    // My messages sit at the start (right in Hebrew), the other side's at the end.
    return Align(
      alignment: m.mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          key: ValueKey('inquiry-message-${m.id}'),
          margin: const EdgeInsets.only(bottom: Space.m),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: m.mine
                ? t.accent.withValues(alpha: .14)
                : t.muted.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(Corners.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.mine ? 'אני' : m.name} · ${inquiryTime(m.createdAt)}',
                style: TextStyle(
                  color: m.fromCommittee ? t.accent : t.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Space.xs),
              SelectableText(m.body),
            ],
          ),
        ),
      ),
    );
  }
}
