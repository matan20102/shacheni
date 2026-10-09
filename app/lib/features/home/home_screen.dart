import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/membership.dart';
import '../../data/providers.dart';

class _Action {
  const _Action(this.text, this.icon, this.tone, this.route);
  final String text;
  final IconData icon;
  final Tone tone;
  final String route;
}

/// S11 — "What can I do in my building right now?"
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  List<_Action> _actions(BuildContext c, DemoData d) {
    final l = c.l10n;
    final lang = c.lang;
    final out = <_Action>[];

    for (final r in d.reservations) {
      if (r.ownerId == DemoData.meId && r.status == ReservationStatus.requested) {
        out.add(_Action(l.actRespondRequest(d.person(r.requesterId).shortName(lang), r.spaceLabel),
            Icons.directions_car_rounded, Tone.accent, '/parking/my-listing/${r.listingId}'));
      }
      if (r.requesterId == DemoData.meId && r.status == ReservationStatus.accepted) {
        out.add(_Action(l.actConfirmReservation(r.spaceLabel), Icons.event_available_rounded, Tone.accent,
            '/parking/reservation/${r.id}'));
      }
    }
    for (final q in d.requests) {
      if (q.requesterId == DemoData.meId) {
        if (q.status == RequestStatus.offerReceived && q.offers.any((o) => o.status == OfferStatus.pending)) {
          final o = q.offers.firstWhere((o) => o.status == OfferStatus.pending);
          out.add(_Action(l.actOfferReceived(d.person(o.helperId).shortName(lang)), Icons.local_offer_rounded,
              Tone.accent, '/packages/request/${q.id}'));
        }
        if (q.status == RequestStatus.collected && q.arrivedAt != null) {
          out.add(_Action(l.actHelperArrived(d.person(q.helperId ?? '').shortName(lang)),
              Icons.directions_walk_rounded, Tone.accent, '/packages/request/${q.id}'));
        } else if (q.status == RequestStatus.collected) {
          out.add(_Action(l.actShowCode, Icons.pin_rounded, Tone.primary, '/packages/request/${q.id}'));
        }
        if (q.status == RequestStatus.delivered && q.handoffMethod == HandoffMethod.doorPhoto) {
          out.add(_Action(l.actViewPhoto, Icons.photo_camera_rounded, Tone.success, '/packages/request/${q.id}/photo'));
        }
      }
      if (q.helperId == DemoData.meId &&
          (q.status == RequestStatus.accepted || q.status == RequestStatus.collected)) {
        out.add(_Action(l.actHelperJob(d.person(q.requesterId).shortName(lang)), Icons.inventory_2_rounded,
            Tone.primary, '/packages/request/${q.id}'));
      }
    }
    for (final t in d.paymentActions) {
      final other = d.person(t.payerId == DemoData.meId ? t.payeeId : t.payerId).shortName(lang);
      if (t.payerId == DemoData.meId) {
        out.add(_Action(l.actPayPay(fmtAmount(t.amountMinor), other), Icons.payments_rounded, Tone.warn,
            '/transaction/${t.id}'));
      } else {
        out.add(_Action(l.actPayReceived(fmtAmount(t.amountMinor), other), Icons.payments_rounded, Tone.info,
            '/transaction/${t.id}'));
      }
    }
    for (final t in d.myTxns) {
      if (t.status == TxStatus.completed && !t.ratedByMe) {
        final other = d.person(t.payerId == DemoData.meId ? t.payeeId : t.payerId).shortName(lang);
        out.add(_Action(l.actRate(other), Icons.star_rounded, Tone.accent, '/transaction/${t.id}'));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final actions = _actions(context, d);
    final soon = d.reservations
        .where((r) =>
            (r.requesterId == DemoData.meId || r.ownerId == DemoData.meId) &&
            r.status == ReservationStatus.confirmed)
        .toList();
    final parking = d.listings
        .where((x) => x.ownerId != DemoData.meId && x.status == ListingStatus.available)
        .take(5)
        .toList();
    final pickups = d.requests
        .where((x) =>
            x.requesterId != DemoData.meId &&
            (x.status == RequestStatus.open || x.status == RequestStatus.offerReceived) &&
            x.deadline.isAfter(DateTime.now()))
        .take(3)
        .toList();

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 14, 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.apartment_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(currentBuildingName(ref, context), style: AppText.smallBold.copyWith(color: AppColors.ink)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton.filledTonal(
                        tooltip: l.notificationsTooltip,
                        style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                        onPressed: () => context.push('/notifications'),
                        icon: const Icon(Icons.notifications_none_rounded, color: AppColors.ink),
                      ),
                      if (d.unreadCount > 0)
                        PositionedDirectional(
                          top: 6,
                          end: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(l.homeGreeting(d.me.first(lang)), style: AppText.h1),
            const SizedBox(height: 2),
            Text(l.homeQuestion, style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _QuickAction(Icons.search_rounded, l.qaFindParking, AppColors.primary, AppColors.primarySoft,
                    () => context.go('/parking')),
                _QuickAction(Icons.local_parking_rounded, l.qaShareParking, AppColors.accent, AppColors.accentSoft,
                    () => context.push(d.myActiveSpaces.isEmpty ? '/parking/spaces' : '/parking/publish')),
                _QuickAction(Icons.add_box_rounded, l.qaRequestPickup, AppColors.info, AppColors.infoSoft,
                    () => context.push('/packages/new')),
                _QuickAction(Icons.volunteer_activism_rounded, l.qaHelp, AppColors.success, AppColors.successSoft,
                    () => context.go('/packages')),
              ],
            ),
            if (actions.isNotEmpty) ...[
              SectionHeader(l.needsAction),
              for (final a in actions.take(4)) _ActionCard(a),
            ],
            if (soon.isNotEmpty) ...[
              SectionHeader(l.happeningSoon),
              for (final r in soon)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  onTap: () => context.push('/parking/reservation/${r.id}'),
                  child: Row(
                    children: [
                      const _IconBadge(Icons.local_parking_rounded, Tone.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.parkingLabel(r.spaceLabel), style: AppText.bodyBold),
                            Text(fmtWindow(context, r.start, r.end), style: AppText.small),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.inkFaint, textDirection: Directionality.of(context)),
                    ],
                  ),
                ),
            ],
            SectionHeader(l.parkingNow, action: l.seeAll, onAction: () => context.go('/parking')),
            if (parking.isEmpty)
              EmptyState(icon: Icons.local_parking_rounded, title: l.nothingYet, message: l.beFirst)
            else
              SizedBox(
                height: 132,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    for (final x in parking)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: _ListingCard(x, d),
                      ),
                  ],
                ),
              ),
            SectionHeader(l.pickupNeighbors, action: l.seeAll, onAction: () => context.go('/packages')),
            if (pickups.isEmpty)
              EmptyState(icon: Icons.inventory_2_outlined, title: l.noRequestsTitle, message: l.noRequestsMsg)
            else
              for (final p in pickups) PickupCard(p, d),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.color, this.bg, this.onTap);
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 24),
          ),
          Text(label, style: AppText.bodyBold, maxLines: 2),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, this.tone);
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, color: c.fg, size: 22),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.a);
  final _Action a;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push(a.route),
      borderColor: toneColors(a.tone).fg.withValues(alpha: 0.35),
      child: Row(
        children: [
          _IconBadge(a.icon, a.tone),
          const SizedBox(width: 12),
          Expanded(child: Text(a.text, style: AppText.bodyMedium)),
          Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint, textDirection: Directionality.of(context)),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard(this.x, this.d);
  final ParkingListing x;
  final DemoData d;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final owner = d.person(x.ownerId);
    return SizedBox(
      width: 200,
      child: AppCard(
        onTap: () => context.push('/parking/listing/${x.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.parkingLabel(x.spaceLabel), style: AppText.h3)),
                Text(x.priceMinor == 0 ? l.free : fmtMoney(x.priceMinor), style: AppText.price.copyWith(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 4),
            Text(fmtWindow(context, x.start, x.end), style: AppText.small, maxLines: 2),
            const Spacer(),
            Row(
              children: [
                PersonAvatar(owner, size: 24),
                const SizedBox(width: 6),
                Expanded(child: Text(owner.shortName(context.lang), style: AppText.small, maxLines: 1)),
                if (x.instant) const Icon(Icons.bolt_rounded, size: 16, color: AppColors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for an open pickup request (shared by Home and the Help list).
class PickupCard extends StatelessWidget {
  const PickupCard(this.q, this.d, {super.key});
  final DeliveryRequest q;
  final DemoData d;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = context.lang;
    final who = d.person(q.requesterId);
    final urgent = q.deadline.difference(DateTime.now()) < const Duration(hours: 1);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/packages/request/${q.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(Icons.inventory_2_rounded, Tone.info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.location.of(lang), style: AppText.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(q.description.of(lang), style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(q.rewardMinor == 0 ? l.free : fmtMoney(q.rewardMinor), style: AppText.price.copyWith(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PersonAvatar(who, size: 22),
              const SizedBox(width: 6),
              Text(who.shortName(lang), style: AppText.small),
              const SizedBox(width: 6),
              RatingText(who),
              const Spacer(),
              StatusChip(
                '${l.untilTime(fmtTime(context, q.deadline))} · ${fmtCountdown(context, q.deadline)}',
                tone: urgent ? Tone.danger : Tone.neutral,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          if (q.doorAllowed) ...[
            const SizedBox(height: 8),
            StatusChip(l.doorOkBadge, tone: Tone.success, icon: Icons.door_front_door_outlined),
          ],
        ],
      ),
    );
  }
}


