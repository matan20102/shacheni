import 'package:flutter/material.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/committee_repository.dart';
import '../../data/building/parking_repository.dart';
import 'committee_screen.dart' show committeeDate, committeeTitle, shekels;
import 'glass_widgets.dart';
import 'parking_screen.dart' show parkingTime;

/// The resident's personal corner of the home tab: what they still owe the
/// committee, the parking they shared or booked, and what they published.
/// Everything comes from the same reads the other tabs already use, so it
/// needs nothing new on the server.
class MyHomeSummary extends StatefulWidget {
  const MyHomeSummary({
    super.key,
    required this.committee,
    required this.parking,
    required this.buildingId,
    required this.posts,
    required this.onCommittee,
    required this.onParking,
    required this.onPost,
    required this.onCompose,
  });
  final CommitteeRepository committee;
  final ParkingRepository parking;
  final String buildingId;

  /// The board posts loaded for the building; only the resident's own show.
  final List<BoardPost> posts;
  final VoidCallback onCommittee, onParking, onCompose;
  final ValueChanged<String> onPost;

  /// How many rows each section shows before "לכל ..." takes over.
  static const rows = 3;

  @override
  State<MyHomeSummary> createState() => _MyHomeSummaryState();
}

class _MyHomeSummaryState extends State<MyHomeSummary> {
  List<CommitteeCharge>? charges;
  List<ParkingOffer>? parking;
  bool committeeFailed = false, parkingFailed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MyHomeSummary old) {
    super.didUpdateWidget(old);
    if (old.buildingId != widget.buildingId) {
      charges = parking = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => committeeFailed = parkingFailed = false);
    await Future.wait([
      () async {
        try {
          final s = await widget.committee.load(widget.buildingId);
          if (!mounted || generation != _generation) return;
          setState(
            () =>
                charges = s.charges.where((c) => !c.settled).toList()
                  ..sort((a, b) => a.dueOn.compareTo(b.dueOn)),
          );
        } catch (_) {
          if (mounted && generation == _generation) {
            setState(() => committeeFailed = true);
          }
        }
      }(),
      () async {
        try {
          final s = await widget.parking.load(widget.buildingId);
          if (!mounted || generation != _generation) return;
          final now = DateTime.now();
          setState(
            () => parking =
                s.offers
                    .where((o) => o.endsAt.isAfter(now))
                    .where((o) => o.status != 'cancelled')
                    .where((o) => o.ownSpace || o.myBooking)
                    .toList()
                  ..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
          );
        } catch (_) {
          if (mounted && generation == _generation) {
            setState(() => parkingFailed = true);
          }
        }
      }(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.posts.where((p) => p.mine).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final open = charges;
    final owed = open
        ?.where((c) => c.myStatus.isEmpty)
        .fold<int>(0, (sum, c) => sum + c.amount);
    final openRequests = mine
        .where((p) => p.kind == PostKind.request && !p.closed)
        .length;
    return Column(
      key: const Key('my-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.l),
        Row(
          children: [
            Expanded(
              child: _Stat(
                key: const Key('my-home-stat-committee'),
                icon: Icons.account_balance_wallet_outlined,
                value: owed == null
                    ? '…'
                    : owed == 0
                    ? '✓'
                    : shekels(owed),
                label: owed == 0 ? 'אין חוב לוועד' : 'לתשלום לוועד',
                onTap: widget.onCommittee,
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: _Stat(
                key: const Key('my-home-stat-parking'),
                icon: Icons.local_parking_rounded,
                value: parking == null ? '…' : '${parking!.length}',
                label: 'חניות פעילות',
                onTap: widget.onParking,
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: _Stat(
                key: const Key('my-home-stat-requests'),
                icon: Icons.volunteer_activism_outlined,
                value: '$openRequests',
                label: 'בקשות פתוחות',
                onTap: mine.isEmpty
                    ? widget.onCompose
                    : () => widget.onPost(
                        (mine.firstWhere(
                          (p) => p.kind == PostKind.request && !p.closed,
                          orElse: () => mine.first,
                        )).id,
                      ),
              ),
            ),
          ],
        ),
        SectionTitle(
          'לתשלום לוועד',
          action: TextButton(
            onPressed: widget.onCommittee,
            child: const Text('לוועד הבית'),
          ),
        ),
        if (committeeFailed)
          _Retry('לא הצלחנו לטעון את התשלומים.', _load)
        else if (open == null)
          const _Placeholder()
        else if (open.isEmpty)
          const _Quiet(
            Icons.check_circle_outline_rounded,
            'אין תשלומים פתוחים. הכול מסודר.',
          )
        else
          _Card(
            children: [
              for (final c in open.take(MyHomeSummary.rows))
                _chargeRow(context, c),
              if (open.length > MyHomeSummary.rows)
                _more('ועוד ${open.length - MyHomeSummary.rows}'),
            ],
          ),
        SectionTitle(
          'החניות שלי',
          action: TextButton(
            onPressed: widget.onParking,
            child: const Text('לחניה'),
          ),
        ),
        if (parkingFailed)
          _Retry('לא הצלחנו לטעון את החניות.', _load)
        else if (parking == null)
          const _Placeholder()
        else if (parking!.isEmpty)
          const _Quiet(
            Icons.local_parking_rounded,
            'אין כרגע חניה ששיתפת או הזמנת.',
          )
        else
          _Card(
            children: [
              for (final o in parking!.take(MyHomeSummary.rows))
                _parkingRow(context, o),
              if (parking!.length > MyHomeSummary.rows)
                _more('ועוד ${parking!.length - MyHomeSummary.rows}'),
            ],
          ),
        SectionTitle(
          'הפרסומים שלי',
          action: TextButton(
            onPressed: widget.onCompose,
            child: const Text('פרסום חדש'),
          ),
        ),
        if (mine.isEmpty)
          const _Quiet(
            Icons.edit_note_rounded,
            'עוד לא פרסמת בלוח. בקשה או עדכון יופיעו כאן.',
          )
        else
          _Card(
            children: [
              for (final p in mine.take(MyHomeSummary.rows))
                _postRow(context, p),
              if (mine.length > MyHomeSummary.rows)
                _more('ועוד ${mine.length - MyHomeSummary.rows}'),
            ],
          ),
      ],
    );
  }

  Widget _chargeRow(BuildContext context, CommitteeCharge c) {
    final t = context.glass;
    final late =
        c.myStatus.isEmpty &&
        c.dueOn.isBefore(DateUtils.dateOnly(DateTime.now()));
    return _Row(
      key: ValueKey('my-home-charge-${c.id}'),
      icon: Icons.receipt_long_outlined,
      title: committeeTitle(c),
      subtitle: c.myStatus == 'reported'
          ? 'סימנת ששילמת · ממתין לאישור הוועד'
          : late
          ? 'עבר המועד · ${committeeDate(c.dueOn)}'
          : 'עד ${committeeDate(c.dueOn)}',
      subtitleColor: late ? t.error : null,
      trailing: shekels(c.amount),
      onTap: widget.onCommittee,
    );
  }

  Widget _parkingRow(BuildContext context, ParkingOffer o) {
    final space = [
      o.space.label,
      if (o.space.level.isNotEmpty) o.space.level,
    ].join(' · ');
    final String state;
    if (o.ownSpace) {
      state = o.status == 'booked'
          ? 'שיתפת · הוזמנה${o.bookerName.isEmpty ? '' : ' על ידי ${o.bookerName}'}'
          : 'שיתפת · עדיין פנויה';
    } else {
      state = 'הזמנת · של דירה ${o.apartment}';
    }
    final now = DateTime.now();
    return _Row(
      key: ValueKey('my-home-parking-${o.id}'),
      icon: o.ownSpace
          ? Icons.favorite_border_rounded
          : Icons.directions_car_outlined,
      title: o.space.label.startsWith('חניה') ? space : 'חניה $space',
      subtitle:
          '$state\n${parkingTime(o.startsAt)} עד ${parkingTime(o.endsAt)}',
      trailing: o.startsAt.isBefore(now) ? 'עכשיו' : null,
      onTap: widget.onParking,
    );
  }

  Widget _postRow(BuildContext context, BoardPost p) {
    final replies = p.replies.length;
    final kind = p.kind == PostKind.request
        ? (p.closed ? 'בקשה · טופלה' : 'בקשה · פתוחה')
        : 'עדכון';
    return _Row(
      key: ValueKey('my-home-post-${p.id}'),
      icon: p.kind == PostKind.request
          ? (p.closed
                ? Icons.task_alt_rounded
                : Icons.volunteer_activism_outlined)
          : Icons.campaign_outlined,
      title: p.text.replaceAll('\n', ' '),
      subtitle:
          '$kind · ${replies == 0
              ? 'אין תגובות עדיין'
              : replies == 1
              ? 'תגובה אחת'
              : '$replies תגובות'}',
      onTap: () => widget.onPost(p.id),
    );
  }

  Widget _more(String text) => Padding(
    padding: const EdgeInsets.only(top: Space.s),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: context.glass.muted),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String value, label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value',
    excludeSemantics: true,
    child: Pressable(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Corners.card),
        child: GlassPanel(
          radius: Corners.card,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.m,
            vertical: Space.m,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: context.glass.accent, size: 22),
              const SizedBox(height: Space.s),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.glass.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: Space.s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.subtitleColor,
  });
  final IconData icon;
  final String title, subtitle;
  final String? trailing;
  final Color? subtitleColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Corners.control),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.s,
            vertical: Space.s,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Space.s),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(Corners.chip),
                ),
                child: Icon(icon, color: t.accent, size: 20),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: subtitleColor ?? t.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.s),
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              Icon(Icons.chevron_left_rounded, color: t.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(Space.l),
    child: Row(
      children: [
        Icon(icon, color: context.glass.muted, size: 20),
        const SizedBox(width: Space.m),
        Expanded(
          child: Text(text, style: TextStyle(color: context.glass.muted)),
        ),
      ],
    ),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => const GlassPanel(
    padding: EdgeInsets.all(Space.l),
    child: SizedBox(
      height: 20,
      child: Center(child: LinearProgressIndicator(minHeight: 2)),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry(this.text, this.onRetry);
  final String text;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(Space.l),
    child: Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: context.glass.error, size: 20),
        const SizedBox(width: Space.m),
        Expanded(child: Text(text)),
        TextButton(onPressed: onRetry, child: const Text('ניסיון נוסף')),
      ],
    ),
  );
}
