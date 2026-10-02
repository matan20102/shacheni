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
import '../home/home_screen.dart' show PickupCard;
import '../money/payment_panel.dart';
import 'door_delivery.dart';

/// S22 + S25 — Packages tab: Help | Mine.
class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  int _tab = 0;
  int _mineTab = 0;
  bool _today = false;
  bool _reward = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.pkgTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: PillTabs(labels: [l.segHelp, l.segMine], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
          Expanded(child: _tab == 0 ? _help(context) : _mine(context)),
        ],
      ),
    );
  }

  Widget _help(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final now = DateTime.now();
    var items = d.requests
        .where((x) =>
            x.requesterId != DemoData.meId &&
            (x.status == RequestStatus.open || x.status == RequestStatus.offerReceived) &&
            x.deadline.isAfter(now))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    if (_today) items = items.where((x) => sameDay(x.deadline, now)).toList();
    if (_reward) items.sort((a, b) => b.rewardMinor.compareTo(a.rewardMinor));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Wrap(
          spacing: 8,
          children: [
            FilterChip(label: Text(l.filterToday), selected: _today, onSelected: (v) => setState(() => _today = v)),
            FilterChip(label: Text(l.filterReward), selected: _reward, onSelected: (v) => setState(() => _reward = v)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: l.noRequestsTitle,
            message: l.noRequestsMsg,
            actionLabel: l.qaRequestPickup,
            onAction: () => context.push('/packages/new'),
          )
        else
          for (final x in items) PickupCard(x, d),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => context.push('/packages/new'),
          icon: const Icon(Icons.add_rounded),
          label: Text(l.qaRequestPickup),
        ),
      ],
    );
  }

  Widget _mine(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final mineReq = d.requests.where((x) => x.requesterId == DemoData.meId).toList();
    final myOffers = d.requests
        .where((x) => x.requesterId != DemoData.meId && x.offers.any((o) => o.helperId == DemoData.meId))
        .toList();
    final list = _mineTab == 0 ? mineReq : myOffers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        PillTabs(labels: [l.segMyRequests, l.segMyOffers], index: _mineTab, onChanged: (i) => setState(() => _mineTab = i)),
        const SizedBox(height: 14),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: _mineTab == 0 ? l.qaRequestPickup : l.qaHelp,
            actionLabel: _mineTab == 0 ? l.qaRequestPickup : l.qaHelp,
            onAction: () => _mineTab == 0 ? context.push('/packages/new') : setState(() => _tab = 0),
          )
        else
          for (final x in list)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => context.push('/packages/request/${x.id}'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.location.of(lang), style: AppText.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          _mineTab == 0
                              ? l.untilTime(fmtDayTime(context, x.deadline))
                              : d.person(x.requesterId).shortName(lang),
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(x.rewardMinor == 0 ? l.free : fmtMoney(x.rewardMinor), style: AppText.price.copyWith(fontSize: 17)),
                      const SizedBox(height: 4),
                      StatusChip(requestStatusOf(context, x.status).label, tone: requestStatusOf(context, x.status).tone),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// S23 — new pickup request.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _location = TextEditingController();
  final _desc = TextEditingController();
  final _notes = TextEditingController();
  final _ref = TextEditingController();
  late DateTime _deadline;
  int _reward = 10;
  bool _door = false;
  bool _ack1 = false;
  bool _ack2 = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(const Duration(hours: 3));
  }

  @override
  void dispose() {
    for (final c in [_location, _desc, _notes, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tooSoon = _deadline.difference(DateTime.now()) < const Duration(minutes: 30);
    final ok = _location.text.trim().isNotEmpty && _desc.text.trim().isNotEmpty && !tooSoon && _ack1 && _ack2;

    return Scaffold(
      appBar: AppBar(title: Text(l.newPickupTitle)),
      body: PageBody(
        children: [
          TextField(
            controller: _location,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.pickupLocation,
              hintText: l.pickupLocationHint,
              errorText: _submitted && _location.text.trim().isEmpty ? l.fieldRequired : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.pkgDescription,
              hintText: l.pkgDescriptionHint,
              errorText: _submitted && _desc.text.trim().isEmpty ? l.fieldRequired : null,
            ),
          ),
          const SizedBox(height: 12),
          DateTimeField(
            label: l.deadlineLabel,
            value: _deadline,
            errorText: tooSoon ? l.deadlineTooSoon : null,
            onChanged: (v) => setState(() => _deadline = v),
          ),
          const SizedBox(height: 16),
          Text(l.rewardChoose, style: AppText.smallBold),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in [0, 5, 10, 15, 20])
                ChoiceChip(
                  label: Text(r == 0 ? l.free : '₪$r'),
                  selected: _reward == r,
                  onSelected: (_) => setState(() => _reward = r),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(controller: _notes, maxLines: 2, decoration: InputDecoration(labelText: l.notesLabel)),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _ref,
              decoration: InputDecoration(
                labelText: l.pickupRef,
                helperText: l.pickupRefHint,
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: l.handoffPlace),
            child: Text(l.defaultLobby, style: AppText.body),
          ),
          const SizedBox(height: 8),
          AppCard(
            margin: const EdgeInsets.only(top: 8),
            color: _door ? AppColors.successSoft : AppColors.surface,
            borderColor: _door ? AppColors.success : AppColors.line,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _door,
              onChanged: (v) => setState(() => _door = v),
              secondary: const Icon(Icons.door_front_door_outlined, color: AppColors.success),
              title: Text(l.doorToggle, style: AppText.bodyMedium),
              subtitle: Text(l.doorToggleHint, style: AppText.tiny),
            ),
          ),
          const SizedBox(height: 6),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _ack1,
            onChanged: (v) => setState(() => _ack1 = v ?? false),
            title: Text(l.ackProhibited, style: AppText.body),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _ack2,
            onChanged: (v) => setState(() => _ack2 = v ?? false),
            title: Text(l.ackThirdParty, style: AppText.body),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              setState(() => _submitted = true);
              if (!ok) return;
              late DeliveryRequest created;
              ref.read(demoProvider.notifier).act((d) => created = d.createRequest(
                    location: _location.text.trim(),
                    description: _desc.text.trim(),
                    deadline: _deadline,
                    rewardMinor: _reward * 100,
                    notes: _notes.text.trim(),
                    reference: _ref.text.trim(),
                    handoffPlace: Bi(l.defaultLobby),
                    doorAllowed: _door,
                  ));
              showSnack(context, l.postedSnack);
              context.pushReplacement('/packages/request/${created.id}');
            },
            child: Text(l.postRequest),
          ),
        ],
      ),
    );
  }
}

/// Dispatches to the right view of one request: requester (S26), accepted helper (S27)
/// or public/offer view (S24).
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(demoProvider).data;
    final q = d.request(id);
    if (q.requesterId == DemoData.meId) return RequesterView(id: id);
    if (q.helperId == DemoData.meId) return HelperJobView(id: id);
    return PublicRequestView(id: id);
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary(this.q, this.d);
  final DeliveryRequest q;
  final DemoData d;


  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = context.lang;
    final st = requestStatusOf(context, q.status);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(q.location.of(lang), style: AppText.h2)),
              StatusChip(st.label, tone: st.tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(q.description.of(lang), style: AppText.body),
          const Divider(height: 24),
          KeyValueRow(l.deadlineLabel, '${fmtDayTime(context, q.deadline)} · ${fmtCountdown(context, q.deadline)}'),
          KeyValueRow(l.rewardLabel, q.rewardMinor == 0 ? l.free : fmtMoney(q.rewardMinor)),
          if (!q.handoffPlace.isEmpty) KeyValueRow(l.handoffPlace, q.handoffPlace.of(lang)),
          if (!q.notes.isEmpty) KeyValueRow(l.notesLabel, q.notes.of(lang)),
          if (q.doorAllowed) ...[
            const SizedBox(height: 6),
            StatusChip(l.doorOkBadge, tone: Tone.success, icon: Icons.door_front_door_outlined),
          ],
        ],
      ),
    );
  }
}

/// S24 — request as seen by another resident (no apartment, no pickup reference).
class PublicRequestView extends ConsumerWidget {
  const PublicRequestView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final q = d.request(id);
    final who = d.person(q.requesterId);
    final mine = d.myOffer(q);
    final open = q.status == RequestStatus.open || q.status == RequestStatus.offerReceived;

    return Scaffold(
      appBar: AppBar(title: Text(l.pkgTitle)),
      body: PageBody(
        children: [
          _RequestSummary(q, d),
          const SizedBox(height: 14),
          AppCard(
            onTap: () => context.push('/profile/${who.id}'),
            child: PersonLine(who, size: 46),
          ),
          const SizedBox(height: 14),
          InfoBanner(l.hiddenDetails, icon: Icons.lock_outline_rounded),
          const SizedBox(height: 18),
          if (mine != null) ...[
            InfoBanner(l.offerPending, icon: Icons.hourglass_top_rounded, tone: Tone.warn),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(demoProvider.notifier).act((d) => d.withdrawOffer(id)),
              child: Text(l.withdrawOffer),
            ),
            DemoButton(l.demoAcceptOffer(who.first(context.lang)), onPressed: () {
              ref.read(demoProvider.notifier).act((d) => d.acceptOffer(id, mine.id));
            }),
          ] else if (open)
            FilledButton(onPressed: () => _offerSheet(context, ref, q), child: Text(l.offerToPickup)),
        ],
      ),
    );
  }

  void _offerSheet(BuildContext context, WidgetRef ref, DeliveryRequest q) {
    DateTime planned = DateTime.now().add(const Duration(hours: 1));
    final msg = TextEditingController();
    showAppSheet<void>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final l = ctx.l10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.offerSheetTitle, style: AppText.h2),
            const SizedBox(height: 14),
            DateTimeField(label: l.plannedTime, value: planned, onChanged: (v) => setState(() => planned = v)),
            const SizedBox(height: 12),
            TextField(controller: msg, maxLines: 2, decoration: InputDecoration(labelText: l.messageOptional)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => d.makeOffer(q.id, message: msg.text.trim(), plannedAt: planned));
                Navigator.pop(ctx);
                showSnack(context, l.offerSentSnack);
              },
              child: Text(l.sendOffer),
            ),
          ],
        );
      });
    });
  }
}

/// S26 — requester's view of their own request.
class RequesterView extends ConsumerWidget {
  const RequesterView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final q = d.request(id);
    final lang = context.lang;
    final act = ref.read(demoProvider.notifier).act;
    final helper = q.helperId == null ? null : d.person(q.helperId!);
    final tx = q.txId == null ? null : d.txn(q.txId!);
    final pendingOffers = q.offers.where((o) => o.status == OfferStatus.pending).toList();
    final preCollect = q.status == RequestStatus.open || q.status == RequestStatus.offerReceived;
    final inFlight = q.status == RequestStatus.accepted || q.status == RequestStatus.collected;
    final terminal = [RequestStatus.cancelled, RequestStatus.expired].contains(q.status);

    return Scaffold(
      appBar: AppBar(title: Text(l.pkgTitle)),
      body: PageBody(
        children: [
          _RequestSummary(q, d),
          if (!terminal) ...[
            const SizedBox(height: 14),
            AppCard(
              child: StepperBar(
                labels: [l.stOpen, l.stOffers, l.stAccepted, l.stCollected, l.stDelivered, l.stCompleted],
                current: requestStep(q.status),
              ),
            ),
          ],
          if (preCollect) ...[
            SectionHeader(l.offersTitle),
            if (pendingOffers.isEmpty) ...[
              AppCard(child: Text(l.noOffersYet, style: AppText.small)),
              DemoButton(l.demoOffer, onPressed: () => act((d) => d.simulateOffer(id))),
            ] else
              for (final o in pendingOffers)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PersonLine(d.person(o.helperId), onTap: () => context.push('/profile/${o.helperId}')),
                      if (o.plannedAt != null) ...[
                        const SizedBox(height: 8),
                        StatusChip(l.offerAt(fmtTime(context, o.plannedAt!)), tone: Tone.info, icon: Icons.schedule_rounded),
                      ],
                      if (!o.message.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text('“${o.message.of(lang)}”', style: AppText.body),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => act((d) {
                                o.status = OfferStatus.rejected;
                                if (q.offers.every((x) => x.status != OfferStatus.pending)) q.status = RequestStatus.open;
                              }),
                              child: Text(l.decline),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => act((d) => d.acceptOffer(id, o.id)),
                              child: Text(l.accept),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
          if (helper != null && !terminal) ...[
            const SizedBox(height: 14),
            ContactCard(helper, showContact: inFlight || q.status == RequestStatus.delivered, title: l.yourHelper),
          ],
          if (inFlight) ...[
            if (q.arrivedAt != null && q.status == RequestStatus.collected) ...[
              const SizedBox(height: 14),
              AppCard(
                color: AppColors.accentSoft,
                borderColor: AppColors.accent,
                onTap: () => showAllowDoorSheet(context, ref, id),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.arrivalBanner(helper!.shortName(lang)), style: AppText.bodyBold)),
                    Icon(Icons.chevron_right_rounded, textDirection: Directionality.of(context)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pin_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.codePanelTitle, style: AppText.h3)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CodeDisplay(q.code),
                  const SizedBox(height: 12),
                  Text(l.codeHint, style: AppText.small, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: q.regenCount >= 3 ? null : () => act((d) => d.regenerateCode(id)),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('${l.regenerateCode} · ${l.regenLeft('${3 - q.regenCount}')}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (q.doorAllowed)
              InfoBanner(l.doorAllowedNote, icon: Icons.door_front_door_outlined, tone: Tone.success)
            else
              OutlinedButton.icon(
                onPressed: () => act((d) => d.allowDoor(id)),
                icon: const Icon(Icons.door_front_door_outlined),
                label: Text(l.allowDoor),
              ),
          ],
          if (q.handoffMethod == HandoffMethod.doorPhoto && q.status != RequestStatus.cancelled) ...[
            SectionHeader(l.deliveryPhoto),
            AppCard(
              padding: EdgeInsets.zero,
              onTap: () => context.push('/packages/request/$id/photo'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
                    child: const SizedBox(height: 150, width: double.infinity, child: SamplePhoto()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.photoTakenAt(helper?.shortName(lang) ?? '', fmtDayTime(context, q.proofAt ?? DateTime.now())),
                          style: AppText.small,
                        ),
                        if (q.status == RequestStatus.delivered && q.autoConfirmAt != null) ...[
                          const SizedBox(height: 4),
                          Text(l.autoConfirmNote(fmtCountdown(context, q.autoConfirmAt!).replaceFirst(RegExp(r'^\S+\s'), '')),
                              style: AppText.tiny.copyWith(color: AppColors.warn)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (q.status == RequestStatus.delivered) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: () => act((d) => d.confirmDelivery(id)), child: Text(l.confirmReceived)),
              if (tx != null)
                TextButton.icon(
                  onPressed: () => showReportSheet(context, ref, tx),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(l.reportProblem),
                ),
            ],
          ],
          if (tx != null) PaymentPanel(tx.id),
          if (tx != null && tx.status == TxStatus.completed && !tx.ratedByMe) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: () => showRateSheet(context, ref, tx), child: Text(l.rateButton)),
          ],
          // Demo helpers: simulate the helper's side.
          if (q.status == RequestStatus.accepted) DemoButton(l.demoCollected, onPressed: () => act((d) => d.simulateCollected(id))),
          if (q.status == RequestStatus.collected) ...[
            DemoButton(l.demoArrival, onPressed: () => act((d) => d.simulateArrival(id))),
            DemoButton(l.demoEnterCode, onPressed: () => act((d) => d.enterCode(id, q.code))),
            if (q.doorAllowed) DemoButton(l.demoDoorDelivery, onPressed: () => act((d) => d.simulateDoorDelivery(id))),
          ],
          if (preCollect || q.status == RequestStatus.accepted) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () => showCancelSheet(
                context,
                title: l.cancelRequestBtn,
                onConfirm: () => act((d) => d.cancelRequest(id)),
              ),
              child: Text(l.cancelRequestBtn),
            ),
          ],
        ],
      ),
    );
  }
}

/// S27 — the accepted helper's job screen.
class HelperJobView extends ConsumerWidget {
  const HelperJobView({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final q = d.request(id);
    final lang = context.lang;
    final act = ref.read(demoProvider.notifier).act;
    final who = d.person(q.requesterId);
    final tx = q.txId == null ? null : d.txn(q.txId!);
    final st = requestStatusOf(context, q.status);
    final live = q.status == RequestStatus.accepted || q.status == RequestStatus.collected || q.status == RequestStatus.delivered;

    return Scaffold(
      appBar: AppBar(title: Text(l.jobTitle)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l.priceShekel(fmtAmount(q.rewardMinor)), style: AppText.price.copyWith(fontSize: 26))),
                    StatusChip(st.label, tone: st.tone),
                  ],
                ),
                const SizedBox(height: 14),
                StepperBar(
                  labels: [l.stAccepted, l.stCollected, l.stDelivered],
                  current: switch (q.status) {
                    RequestStatus.accepted => 0,
                    RequestStatus.collected => 1,
                    RequestStatus.delivered => 2,
                    _ => 3,
                  },
                ),
              ],
            ),
          ),
          SectionHeader(l.pickupBlock),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.place_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(q.location.of(lang), style: AppText.bodyBold)),
                ]),
                const SizedBox(height: 6),
                Text(q.description.of(lang), style: AppText.small),
                const Divider(height: 22),
                KeyValueRow(l.deadlineLabel, '${fmtDayTime(context, q.deadline)} · ${fmtCountdown(context, q.deadline)}'),
                KeyValueRow(
                  l.pickupRefLabel,
                  '',
                  valueWidget: Row(
                    children: [
                      Directionality(textDirection: TextDirection.ltr, child: Text(q.pickupRef, style: AppText.h3)),
                      const Spacer(),
                      TextButton(onPressed: () => showSnack(context, l.copied), child: Text(l.copy)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(l.deliverTo),
          ContactCard(who, showContact: live, apartment: who.apartment),
          const SizedBox(height: 4),
          KeyValueRow(l.handoffPlace, q.handoffPlace.of(lang)),
          if (tx != null) PaymentPanel(tx.id),
          const SizedBox(height: 16),
          if (q.status == RequestStatus.accepted) ...[
            FilledButton(onPressed: () => act((d) => d.markCollected(id)), child: Text(l.iPickedUp)),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () => showCancelSheet(
                context,
                title: l.withdrawJob,
                onConfirm: () {
                  act((d) => d.helperWithdraw(id));
                  context.pop();
                },
              ),
              child: Text(l.withdrawJob),
            ),
          ],
          if (q.status == RequestStatus.collected) ...[
            FilledButton(onPressed: () => context.push('/packages/request/$id/code'), child: Text(l.enterCode)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: d.arrivalCooldown(q)
                  ? null
                  : () {
                      act((d) => d.notifyArrival(id));
                      showSnack(context, l.arrivalSent(who.shortName(lang)));
                    },
              icon: const Icon(Icons.directions_walk_rounded),
              label: Text(l.imHere),
            ),
            TextButton(onPressed: () => showMethodsSheet(context, ref, id), child: Text(l.cantHandOver)),
          ],
          if (q.status == RequestStatus.delivered) ...[
            InfoBanner(l.doorPhotoSuccess, icon: Icons.check_circle_rounded, tone: Tone.success),
            DemoButton(l.demoConfirmReceived(who.first(lang)), onPressed: () => act((d) => d.confirmDelivery(id))),
          ],
          if (tx != null && tx.status == TxStatus.completed && !tx.ratedByMe)
            FilledButton(onPressed: () => showRateSheet(context, ref, tx), child: Text(l.rateButton)),
          if (tx != null && live)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextButton.icon(
                onPressed: () => showReportSheet(context, ref, tx),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(l.reportProblem),
              ),
            ),
        ],
      ),
    );
  }
}




