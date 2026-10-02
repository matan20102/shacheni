import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/date_field.dart';
import '../../core/format.dart';
import '../../core/status.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/contact_card.dart';
import '../common/sheets.dart';
import '../money/payment_panel.dart';

/// S12 + S16 — Parking tab: Find | Mine.
class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  int _tab = 0;
  int _mineTab = 0;
  int _preset = 0;
  bool _showAll = false;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _applyPreset(0);
  }

  void _applyPreset(int p) {
    final n = DateTime.now();
    _preset = p;
    switch (p) {
      case 0:
        final s = DateTime(n.year, n.month, n.day, n.hour + 1);
        _from = s;
        _to = s.add(const Duration(hours: 3));
      case 1:
        _from = DateTime(n.year, n.month, n.day + 1, 10);
        _to = DateTime(n.year, n.month, n.day + 1, 17);
      default:
        _from = DateTime(n.year, n.month, n.day + 3, 10);
        _to = DateTime(n.year, n.month, n.day + 5, 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.parkingTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: PillTabs(labels: [l.segFind, l.segMine], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
          Expanded(child: _tab == 0 ? _find(context) : _mine(context)),
        ],
      ),
    );
  }

  Widget _find(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final results = d.listings.where((x) {
      if (x.ownerId == DemoData.meId || x.status != ListingStatus.available) return false;
      if (_showAll) return x.end.isAfter(DateTime.now());
      return !x.start.isAfter(_from) && !x.end.isBefore(_to);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(l.whenNeedParking, style: AppText.h3),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final (i, label) in [(0, l.presetTonight), (1, l.presetTomorrow), (2, l.presetWeek)])
              ChoiceChip(
                label: Text(label),
                selected: _preset == i && !_showAll,
                onSelected: (_) => setState(() {
                  _showAll = false;
                  _applyPreset(i);
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DateTimeField(
                label: l.fromLabel,
                value: _from,
                onChanged: (v) => setState(() {
                  _from = v;
                  if (!_to.isAfter(_from)) _to = _from.add(const Duration(hours: 2));
                  _preset = -1;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateTimeField(
                label: l.toLabel,
                value: _to,
                onChanged: (v) => setState(() {
                  _to = v;
                  _preset = -1;
                }),
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _showAll,
          onChanged: (v) => setState(() => _showAll = v),
          title: Text(l.showAllUpcoming, style: AppText.body),
        ),
        const SizedBox(height: 4),
        if (results.isEmpty)
          EmptyState(
            icon: Icons.local_parking_rounded,
            title: l.noSpacesTitle,
            message: l.noSpacesMsg,
            actionLabel: _showAll ? null : l.showAllUpcoming,
            onAction: () => setState(() => _showAll = true),
          )
        else
          for (final x in results) _ResultCard(x, d, covers: !x.start.isAfter(_from) && !x.end.isBefore(_to)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(d.myActiveSpaces.isEmpty ? '/parking/spaces' : '/parking/publish'),
          icon: const Icon(Icons.add_rounded),
          label: Text(l.qaShareParking),
        ),
      ],
    );
  }

  Widget _mine(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        PillTabs(labels: [l.segSharing, l.segRenting], index: _mineTab, onChanged: (i) => setState(() => _mineTab = i)),
        const SizedBox(height: 14),
        if (_mineTab == 0) ...[
          Builder(builder: (context) {
            final mine = d.listings.where((x) => x.ownerId == DemoData.meId).toList();
            final needs = mine
                .where((x) => d.requestsFor(x.id).any((r) => r.status == ReservationStatus.requested))
                .toList();
            final others = mine.where((x) => !needs.contains(x)).toList();
            if (mine.isEmpty) {
              return EmptyState(
                icon: Icons.local_parking_rounded,
                title: l.emptySharing,
                actionLabel: l.qaShareParking,
                onAction: () => context.push(d.myActiveSpaces.isEmpty ? '/parking/spaces' : '/parking/publish'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (needs.isNotEmpty) ...[
                  Text(l.needsResponse, style: AppText.h3),
                  const SizedBox(height: 8),
                  for (final x in needs) _MyListingCard(x, d, highlight: true),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(l.upcoming, style: AppText.h3),
                  const SizedBox(height: 8),
                  for (final x in others) _MyListingCard(x, d),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.push(d.myActiveSpaces.isEmpty ? '/parking/spaces' : '/parking/publish'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.publish),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/parking/spaces'),
                  icon: const Icon(Icons.local_parking_rounded, size: 18),
                  label: Text(l.mySpacesTitle),
                ),
              ],
            );
          }),
        ] else ...[
          Builder(builder: (context) {
            final mine = d.reservations.where((r) => r.requesterId == DemoData.meId).toList();
            if (mine.isEmpty) {
              return EmptyState(icon: Icons.event_busy_rounded, title: l.emptyRenting);
            }
            final needs = mine.where((r) => r.status == ReservationStatus.accepted).toList();
            final live = mine.where((r) => [ReservationStatus.requested, ReservationStatus.confirmed, ReservationStatus.active].contains(r.status)).toList();
            final past = mine.where((r) => !needs.contains(r) && !live.contains(r)).toList();
            Widget group(String title, List<Reservation> rs) => rs.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 6, bottom: 8), child: Text(title, style: AppText.h3)),
                      for (final r in rs)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          onTap: () => context.push('/parking/reservation/${r.id}'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.parkingLabel(r.spaceLabel), style: AppText.bodyBold),
                                    Text(fmtWindow(context, r.start, r.end), style: AppText.small),
                                    Text(d.person(r.ownerId).shortName(lang), style: AppText.small),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(r.priceMinor == 0 ? l.free : fmtMoney(r.priceMinor), style: AppText.price.copyWith(fontSize: 17)),
                                  const SizedBox(height: 4),
                                  StatusChip(reservationStatusOf(context, r.status).label,
                                      tone: reservationStatusOf(context, r.status).tone),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
            return Column(children: [group(l.needsResponse, needs), group(l.upcoming, live), group(l.past, past)]);
          }),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard(this.x, this.d, {required this.covers});
  final ParkingListing x;
  final DemoData d;
  final bool covers;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final owner = d.person(x.ownerId);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push('/parking/listing/${x.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                child: Text(x.spaceLabel, style: AppText.h3.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.parkingLabel(x.spaceLabel), style: AppText.bodyBold),
                    Text(fmtWindow(context, x.start, x.end), style: AppText.small),
                  ],
                ),
              ),
              Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PersonAvatar(owner, size: 24),
              const SizedBox(width: 8),
              Text(owner.shortName(context.lang), style: AppText.small),
              const SizedBox(width: 8),
              RatingText(owner),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (covers) StatusChip(l.coversYourTime, tone: Tone.success, icon: Icons.check_rounded),
              x.instant
                  ? StatusChip(l.instantBadge, tone: Tone.accent, icon: Icons.bolt_rounded)
                  : StatusChip(l.approvalBadge, tone: Tone.neutral, icon: Icons.person_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard(this.x, this.d, {this.highlight = false});
  final ParkingListing x;
  final DemoData d;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final st = listingStatusOf(context, x.status);
    final pending = d.requestsFor(x.id).where((r) => r.status == ReservationStatus.requested).length;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: highlight ? AppColors.accent : AppColors.line,
      onTap: () => context.push('/parking/my-listing/${x.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.parkingLabel(x.spaceLabel), style: AppText.bodyBold),
                Text(fmtWindow(context, x.start, x.end), style: AppText.small),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pending > 0) ...[
                    StatusChip('$pending', tone: Tone.accent, icon: Icons.mark_email_unread_outlined),
                    const SizedBox(width: 4),
                  ],
                  StatusChip(st.label, tone: st.tone),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// S13 — listing detail for a requester (owner view for my own listings).
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final x = d.listing(id);
    if (x.ownerId == DemoData.meId) return MyListingScreen(id: id);
    final owner = d.person(x.ownerId);
    final lang = context.lang;
    final available = x.status == ListingStatus.available;
    return Scaffold(
      appBar: AppBar(title: Text(l.listingDetailTitle)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
                      child: Text(x.spaceLabel, style: AppText.h2.copyWith(color: AppColors.primary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(l.parkingLabel(x.spaceLabel), style: AppText.h1)),
                    Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price.copyWith(fontSize: 26)),
                  ],
                ),
                const SizedBox(height: 14),
                KeyValueRow(l.whenLabel, fmtWindow(context, x.start, x.end)),
                if (!x.description.isEmpty) KeyValueRow(l.descriptionLabel, x.description.of(lang)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  x.instant
                      ? StatusChip(l.instantBadge, tone: Tone.accent, icon: Icons.bolt_rounded)
                      : StatusChip(l.approvalBadge, tone: Tone.neutral, icon: Icons.person_outline_rounded),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeader(l.offeredBy, padding: const EdgeInsets.only(bottom: 8, top: 4)),
          AppCard(
            onTap: () => context.push('/profile/${owner.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PersonLine(owner, size: 46),
                const SizedBox(height: 10),
                Text(l.verifiedResident(d.buildingName.of(lang)), style: AppText.small.copyWith(color: AppColors.success)),
                Text(l.completedCount('${owner.completed}'), style: AppText.small),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InfoBanner(l.paymentNotice, icon: Icons.shield_outlined),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: available ? () => _review(context, ref, x) : null,
            child: Text(x.instant ? l.reserveNow : l.requestAction),
          ),
        ],
      ),
    );
  }

  void _review(BuildContext context, WidgetRef ref, ParkingListing x) {
    final plate = TextEditingController();
    final note = TextEditingController();
    showAppSheet<void>(context, builder: (ctx) {
      final l = ctx.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.reviewTitle, style: AppText.h2),
          const SizedBox(height: 14),
          AppCard(
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.parkingLabel(x.spaceLabel), style: AppText.bodyBold),
                      Text(fmtWindow(ctx, x.start, x.end), style: AppText.small),
                    ],
                  ),
                ),
                Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(controller: plate, decoration: InputDecoration(labelText: l.vehiclePlate)),
          ),
          const SizedBox(height: 12),
          TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: l.noteToOwner)),
          const SizedBox(height: 12),
          InfoBanner(l.paymentNotice, icon: Icons.shield_outlined),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              late Reservation r;
              ref.read(demoProvider.notifier).act((d) => r = d.requestParking(x.id, plate: plate.text, note: note.text));
              Navigator.pop(ctx);
              showSnack(context, x.instant ? l.reservedSnack : l.requestSentSnack);
              context.push('/parking/reservation/${r.id}');
            },
            child: Text(x.instant ? l.reserveNow : l.sendRequest),
          ),
        ],
      );
    });
  }
}

/// S17 — owner view of one of my listings.
class MyListingScreen extends ConsumerWidget {
  const MyListingScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final x = d.listing(id);
    final st = listingStatusOf(context, x.status);
    final reqs = d.requestsFor(id).where((r) => r.status == ReservationStatus.requested).toList();
    final booked = d.requestsFor(id).where((r) => [ReservationStatus.accepted, ReservationStatus.confirmed, ReservationStatus.active, ReservationStatus.completed].contains(r.status)).toList();
    final act = ref.read(demoProvider.notifier).act;

    return Scaffold(
      appBar: AppBar(title: Text(l.parkingLabel(x.spaceLabel))),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(fmtWindow(context, x.start, x.end), style: AppText.h3)),
                    StatusChip(st.label, tone: st.tone),
                  ],
                ),
                const SizedBox(height: 8),
                Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price.copyWith(fontSize: 24)),
                if (x.status == ListingStatus.available) ...[
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: !x.instant,
                    onChanged: (v) => act((d) => d.listing(id).instant = !v),
                    title: Text(l.approveEach, style: AppText.bodyMedium),
                    subtitle: Text(l.approveEachHint, style: AppText.tiny),
                  ),
                ],
              ],
            ),
          ),
          if (booked.isNotEmpty) ...[
            SectionHeader(l.reservationTitle),
            for (final r in booked)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => context.push('/parking/reservation/${r.id}'),
                child: Row(
                  children: [
                    Expanded(child: PersonLine(d.person(r.requesterId))),
                    StatusChip(reservationStatusOf(context, r.status).label, tone: reservationStatusOf(context, r.status).tone),
                  ],
                ),
              ),
          ],
          SectionHeader(l.requestsTitle),
          if (reqs.isEmpty)
            AppCard(child: Text(l.noRequestsYet, style: AppText.small))
          else
            for (final r in reqs)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonLine(d.person(r.requesterId), onTap: () => context.push('/profile/${r.requesterId}')),
                    if (r.plate.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      KeyValueRow(l.vehicleLabel, r.plate),
                    ],
                    if (r.note.isNotEmpty) KeyValueRow(l.noteLabel, r.note),
                    const SizedBox(height: 8),
                    InfoBanner(l.acceptWarn, icon: Icons.info_outline_rounded, tone: Tone.warn),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => act((d) => d.respondReservation(r.id, false)),
                            child: Text(l.decline),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => act((d) => d.respondReservation(r.id, true)),
                            child: Text(l.accept),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          if (x.status == ListingStatus.available) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () => showCancelSheet(
                context,
                title: l.cancelAvailability,
                countsAgainstMe: false,
                onConfirm: () {
                  act((d) => d.cancelListing(id));
                  context.pop();
                },
              ),
              child: Text(l.cancelAvailability),
            ),
          ],
        ],
      ),
    );
  }
}

/// S15 — publish one of my assigned spaces.
class PublishParkingScreen extends ConsumerStatefulWidget {
  const PublishParkingScreen({super.key});

  @override
  ConsumerState<PublishParkingScreen> createState() => _PublishParkingScreenState();
}

class _PublishParkingScreenState extends ConsumerState<PublishParkingScreen> {
  String? _space;
  late DateTime _start;
  late DateTime _end;
  final _price = TextEditingController(text: '10');
  final _desc = TextEditingController();
  bool _approve = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _start = DateTime(n.year, n.month, n.day, n.hour + 1);
    _end = _start.add(const Duration(hours: 5));
  }

  @override
  void dispose() {
    _price.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final spaces = d.myActiveSpaces;
    _space ??= spaces.isEmpty ? null : spaces.first;

    if (spaces.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.publishTitle)),
        body: Center(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: l.noAssignmentTitle,
            message: l.noAssignmentMsg,
            actionLabel: l.requestAssignmentBtn,
            onAction: () => context.push('/parking/spaces/request'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.publishTitle)),
      body: PageBody(
        children: [
          Text(l.chooseSpace, style: AppText.smallBold),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in spaces)
                ChoiceChip(label: Text(s), selected: _space == s, onSelected: (_) => setState(() => _space = s)),
            ],
          ),
          const SizedBox(height: 16),
          DateTimeField(
            label: l.startsLabel,
            value: _start,
            onChanged: (v) => setState(() {
              _start = v;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          DateTimeField(
            label: l.endsLabel,
            value: _end,
            errorText: _error,
            onChanged: (v) => setState(() {
              _end = v;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.priceInput),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final p in [0, 10, 20, 50, 300])
              ActionChip(
                label: Text(p == 0 ? l.free : '₪$p'),
                onPressed: () => setState(() => _price.text = '$p'),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _desc, maxLength: 200, decoration: InputDecoration(labelText: l.descriptionOptional)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _approve,
            onChanged: (v) => setState(() => _approve = v),
            title: Text(l.approveEach, style: AppText.bodyMedium),
            subtitle: Text(l.approveEachHint, style: AppText.tiny),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              if (!_end.isAfter(_start)) {
                setState(() => _error = l.invalidWindow);
                return;
              }
              final clash = d.overlappingListing(_space!, _start, _end);
              if (clash != null) {
                setState(() => _error = l.overlapError);
                return;
              }
              final price = (int.tryParse(_price.text.trim()) ?? 0) * 100;
              late ParkingListing created;
              ref.read(demoProvider.notifier).act((d) => created = d.publishListing(
                    space: _space!,
                    start: _start,
                    end: _end,
                    priceMinor: price,
                    description: _desc.text.trim(),
                    instant: !_approve,
                  ));
              showSnack(context, l.publishedSnack);
              context.pushReplacement('/parking/my-listing/${created.id}');
            },
            child: Text(l.publish),
          ),
        ],
      ),
    );
  }
}

/// S18 + S19 — reservation detail for both roles.
class ReservationScreen extends ConsumerWidget {
  const ReservationScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final r = d.reservation(id);
    final iAmOwner = r.ownerId == DemoData.meId;
    final other = d.person(iAmOwner ? r.requesterId : r.ownerId);
    final st = reservationStatusOf(context, r.status);
    final terminal = [ReservationStatus.cancelled, ReservationStatus.declined, ReservationStatus.expired].contains(r.status);
    final tx = d.txnOfReservation(r);
    final live = tx != null && tx.status != TxStatus.cancelled && tx.status != TxStatus.completed;
    final act = ref.read(demoProvider.notifier).act;
    final name = other.shortName(context.lang);

    return Scaffold(
      appBar: AppBar(title: Text(l.reservationTitle)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.parkingLabel(r.spaceLabel), style: AppText.h2)),
                    StatusChip(st.label, tone: st.tone),
                  ],
                ),
                const SizedBox(height: 14),
                if (!terminal)
                  StepperBar(
                    labels: [l.stepRequested, l.stepAccepted, l.stepConfirmed, l.stepActive, l.stepEnded],
                    current: reservationStep(r.status),
                  ),
                const SizedBox(height: 14),
                KeyValueRow(l.whenLabel, fmtWindow(context, r.start, r.end)),
                KeyValueRow(l.priceLabel, r.priceMinor == 0 ? l.free : fmtMoney(r.priceMinor)),
                if (r.plate.isNotEmpty) KeyValueRow(l.vehicleLabel, r.plate),
                if (r.note.isNotEmpty) KeyValueRow(l.noteLabel, r.note),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ContactCard(other, showContact: live && r.status != ReservationStatus.requested),
          if (r.status == ReservationStatus.accepted && !iAmOwner && r.expiresAt != null) ...[
            const SizedBox(height: 12),
            InfoBanner(l.confirmBy(fmtTime(context, r.expiresAt!)), icon: Icons.timer_outlined, tone: Tone.warn),
          ],
          if (tx != null) PaymentPanel(tx.id),
          const SizedBox(height: 16),
          if (iAmOwner && r.status == ReservationStatus.requested)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => act((d) => d.respondReservation(id, false)),
                    child: Text(l.decline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => act((d) => d.respondReservation(id, true)),
                    child: Text(l.accept),
                  ),
                ),
              ],
            ),
          if (!iAmOwner && r.status == ReservationStatus.accepted)
            FilledButton(onPressed: () => _confirm(context, ref, r, name), child: Text(l.confirmReservation)),
          if (r.status == ReservationStatus.completed && tx != null && tx.status == TxStatus.completed && !tx.ratedByMe)
            FilledButton(onPressed: () => showRateSheet(context, ref, tx), child: Text(l.rateButton)),
          if (tx != null && (tx.status == TxStatus.inProgress || tx.status == TxStatus.awaitingSettlement || tx.status == TxStatus.completed))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: () => showReportSheet(context, ref, tx),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l.reportProblem),
              ),
            ),
          if (r.status == ReservationStatus.requested && !iAmOwner)
            DemoButton(l.demoAcceptReq(name), onPressed: () => act((d) => d.respondReservation(id, true))),
          if (r.status == ReservationStatus.confirmed)
            DemoButton(l.demoEndBooking, onPressed: () => act((d) => d.completeReservation(id))),
          if (!terminal && r.status != ReservationStatus.completed && r.status != ReservationStatus.active) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () => showCancelSheet(
                context,
                title: l.cancelBookingTitle,
                onConfirm: () => act((d) => d.cancelReservation(id)),
              ),
              child: Text(l.cancelTitle),
            ),
          ],
        ],
      ),
    );
  }

  void _confirm(BuildContext context, WidgetRef ref, Reservation r, String name) {
    showAppSheet<void>(context, builder: (ctx) {
      final l = ctx.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.confirmReservation, style: AppText.h2),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.parkingLabel(r.spaceLabel), style: AppText.bodyBold),
                      Text(fmtWindow(ctx, r.start, r.end), style: AppText.small),
                    ],
                  ),
                ),
                Text(r.priceMinor == 0 ? l.free : fmtMoney(r.priceMinor), style: AppText.price),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoBanner(l.confirmSheetBody(name), icon: Icons.shield_outlined),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(demoProvider.notifier).act((d) => d.confirmReservation(r.id));
              Navigator.pop(ctx);
              showSnack(context, l.reservedSnack);
            },
            child: Text(l.confirm),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.notNow)),
        ],
      );
    });
  }
}

/// S20 — my parking spaces (assignments) and S21 — request an assignment.
class MySpacesScreen extends ConsumerWidget {
  const MySpacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      appBar: AppBar(title: Text(l.mySpacesTitle)),
      body: d.assignments.isEmpty
          ? EmptyState(
              icon: Icons.local_parking_rounded,
              title: l.noSpacesLinked,
              actionLabel: l.requestAssignmentBtn,
              onAction: () => context.push('/parking/spaces/request'),
            )
          : PageBody(
              children: [
                for (final a in d.assignments)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                          child: Text(a.spaceLabel, style: AppText.h3.copyWith(color: AppColors.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.parkingLabel(a.spaceLabel), style: AppText.bodyBold)),
                        StatusChip(assignmentStatusOf(context, a.status).label, tone: assignmentStatusOf(context, a.status).tone),
                        if (a.status == AssignmentStatus.requested)
                          IconButton(
                            tooltip: l.withdrawRequestShort,
                            onPressed: () => ref.read(demoProvider.notifier).act((d) => d.withdrawAssignment(a.id)),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => context.push('/parking/spaces/request'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.requestAssignmentBtn),
                ),
              ],
            ),
    );
  }
}

class RequestAssignmentScreen extends ConsumerStatefulWidget {
  const RequestAssignmentScreen({super.key});

  @override
  ConsumerState<RequestAssignmentScreen> createState() => _RequestAssignmentScreenState();
}

class _RequestAssignmentScreenState extends ConsumerState<RequestAssignmentScreen> {
  String? _space;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final taken = d.assignments.where((a) => a.status != AssignmentStatus.rejected && a.status != AssignmentStatus.ended).map((a) => a.spaceLabel).toSet();
    return Scaffold(
      appBar: AppBar(title: Text(l.requestAssignTitle)),
      body: PageBody(
        children: [
          InfoBanner(l.assignHint, icon: Icons.verified_user_outlined),
          const SizedBox(height: 18),
          Text(l.pickSpace, style: AppText.smallBold),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in d.spaceLabels.where((s) => !taken.contains(s)))
                ChoiceChip(label: Text(s), selected: _space == s, onSelected: (_) => setState(() => _space = s)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _space == null
                ? null
                : () {
                    ref.read(demoProvider.notifier).act((d) => d.requestAssignment(_space!));
                    showSnack(context, l.assignSentSnack);
                    context.pop();
                  },
            child: Text(l.sendAssignRequest),
          ),
        ],
      ),
    );
  }
}
