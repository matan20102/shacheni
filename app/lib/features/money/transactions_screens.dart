import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/status.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/sheets.dart';
import 'payment_panel.dart';

/// S32 — transaction detail / receipt.
class TransactionScreen extends ConsumerWidget {
  const TransactionScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final t = d.txn(id);
    final iPay = t.payerId == DemoData.meId;
    final other = d.person(iPay ? t.payeeId : t.payerId);
    final st = txStatusOf(context, t.status);
    final lang = context.lang;
    final isParking = t.type == TxType.parking;

    final events = <(String, DateTime?)>[
      (l.stepConfirmed, t.createdAt),
      (isParking ? l.resCompleted : l.stDelivered, t.serviceDoneAt),
      (l.payConfirmed, t.pay == PaymentStatus.payerConfirmed || t.pay == PaymentStatus.settled ? (t.settledAt ?? t.serviceDoneAt ?? t.createdAt) : null),
      (l.paySettled, t.settledAt),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.txDetailTitle)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isParking ? AppColors.primarySoft : AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(isParking ? Icons.local_parking_rounded : Icons.inventory_2_rounded,
                          color: isParking ? AppColors.primary : AppColors.info),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isParking ? l.parkingLabel(t.title.of(lang)) : t.title.of(lang), style: AppText.h3),
                          Text(isParking ? l.txTypeParking : l.txTypePickup, style: AppText.small),
                        ],
                      ),
                    ),
                    StatusChip(st.label, tone: st.tone),
                  ],
                ),
                const Divider(height: 26),
                Text(
                  '${iPay ? '−' : '+'}${fmtMoney(t.amountMinor)}',
                  style: AppText.display.copyWith(color: iPay ? AppColors.ink : AppColors.success),
                ),
                Text(iPay ? l.youPaid : l.youReceived, style: AppText.small),
                const SizedBox(height: 10),
                if (t.windowStart != null) KeyValueRow(l.whenLabel, fmtWindow(context, t.windowStart!, t.windowEnd!)),
                KeyValueRow(l.counterparty, '', valueWidget: PersonLine(other, size: 30, onTap: () => context.push('/profile/${other.id}'))),
              ],
            ),
          ),
          SectionHeader(l.paymentTimeline),
          AppCard(
            child: Column(
              children: [
                for (final (label, at) in events)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(at == null ? Icons.radio_button_unchecked_rounded : Icons.check_circle_rounded,
                            size: 20, color: at == null ? AppColors.inkFaint : AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(child: Text(label, style: AppText.body.copyWith(color: at == null ? AppColors.inkSoft : AppColors.ink))),
                        if (at != null) Text(fmtDayTime(context, at), style: AppText.small),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PaymentPanel(t.id),
          const SizedBox(height: 16),
          if (t.status == TxStatus.completed && !t.ratedByMe)
            FilledButton(onPressed: () => showRateSheet(context, ref, t), child: Text(l.rateButton)),
          if (t.ratedByMe) InfoBanner(l.alreadyRated, icon: Icons.star_rounded, tone: Tone.success),
          if (t.status == TxStatus.inProgress || t.status == TxStatus.awaitingSettlement || t.status == TxStatus.completed)
            TextButton.icon(
              onPressed: () => showReportSheet(context, ref, t),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(l.reportProblem),
            ),
        ],
      ),
    );
  }
}

/// S40 — history of all my transactions.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final all = d.myTxns;
    final items = all.where((t) {
      switch (_filter) {
        case 1:
          return t.type == TxType.parking;
        case 2:
          return t.type == TxType.delivery;
        case 3:
          return t.payerId == DemoData.meId;
        case 4:
          return t.payeeId == DemoData.meId;
        default:
          return true;
      }
    }).toList();
    final paid = all.where((t) => t.payerId == DemoData.meId && t.pay == PaymentStatus.settled).fold<int>(0, (a, t) => a + t.amountMinor);
    final earned = all.where((t) => t.payeeId == DemoData.meId && t.pay == PaymentStatus.settled).fold<int>(0, (a, t) => a + t.amountMinor);
    final filters = [l.filterAll, l.filterParking, l.filterPickups, l.filterPaid, l.filterReceived];

    return Scaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          AppCard(
            color: AppColors.primarySoft,
            borderColor: AppColors.primarySoft,
            child: Text(l.historyTotals(fmtAmount(earned), fmtAmount(paid)), style: AppText.bodyBold),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < filters.length; i++)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(label: Text(filters[i]), selected: _filter == i, onSelected: (_) => setState(() => _filter = i)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            EmptyState(icon: Icons.receipt_long_outlined, title: l.historyEmpty)
          else
            for (final t in items) _TxRow(t, d),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow(this.t, this.d);
  final Txn t;
  final DemoData d;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = context.lang;
    final iPay = t.payerId == DemoData.meId;
    final other = d.person(iPay ? t.payeeId : t.payerId);
    final st = txStatusOf(context, t.status);
    final isParking = t.type == TxType.parking;
    final when = t.windowStart != null ? fmtWindow(context, t.windowStart!, t.windowEnd!) : DateFormat.MMMd(context.localeTag).format(t.createdAt);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/transaction/${t.id}'),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isParking ? AppColors.primarySoft : AppColors.infoSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(isParking ? Icons.local_parking_rounded : Icons.inventory_2_rounded,
                color: isParking ? AppColors.primary : AppColors.info, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isParking ? l.parkingLabel(t.title.of(lang)) : t.title.of(lang),
                    style: AppText.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$when · ${other.shortName(lang)}', style: AppText.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${iPay ? '−' : '+'}${fmtMoney(t.amountMinor)}',
                  style: AppText.bodyBold.copyWith(color: iPay ? AppColors.ink : AppColors.success)),
              const SizedBox(height: 4),
              StatusChip(st.label, tone: st.tone),
            ],
          ),
        ],
      ),
    );
  }
}

