import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// S34 — cancel confirmation with explicit consequences (PRD flow F22).
Future<void> showCancelSheet(
  BuildContext context, {
  required String title,
  required VoidCallback onConfirm,
  bool countsAgainstMe = true,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) {
      final l = ctx.l10n;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h2),
          const SizedBox(height: 14),
          Text(l.consequences, style: AppText.smallBold),
          const SizedBox(height: 8),
          for (final t in [l.consOther, l.consRefund, if (countsAgainstMe) l.consCounter])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: AppText.body)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
              showSnack(context, l.cancelledSnack);
            },
            child: Text(l.confirmCancel),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l.keepIt)),
        ],
      );
    },
  );
}

/// S33 — rate the other participant (1–5 stars, optional comment).
Future<void> showRateSheet(BuildContext context, WidgetRef ref, Txn t) {
  return showAppSheet<void>(
    context,
    builder: (ctx) {
      var stars = 0;
      return StatefulBuilder(builder: (ctx, setState) {
        final l = ctx.l10n;
        final d = ref.read(demoProvider).data;
        final other = d.person(t.payerId == DemoData.meId ? t.payeeId : t.payerId);
        return Column(
          children: [
            PersonAvatar(other, size: 64),
            const SizedBox(height: 12),
            Text(l.rateTitle(other.shortName(ctx.lang)), style: AppText.h2, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            StarRating(value: stars, onChanged: (v) => setState(() => stars = v)),
            const SizedBox(height: 16),
            TextField(maxLines: 3, decoration: InputDecoration(hintText: l.rateComment)),
            const SizedBox(height: 8),
            Text(l.rateHidden, style: AppText.tiny, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: stars == 0
                  ? null
                  : () {
                      ref.read(demoProvider.notifier).act((d) => d.rate(t.id, stars));
                      Navigator.pop(ctx);
                      showSnack(context, l.rateThanks);
                    },
              child: Text(l.submit),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.notNow)),
          ],
        );
      });
    },
  );
}

/// S35 — report a problem (opens a dispute; automation is paused).
Future<void> showReportSheet(BuildContext context, WidgetRef ref, Txn t, {String? preset}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) {
      final reasons = t.type == TxType.parking
          ? ['space_occupied', 'payment_not_received', 'other']
          : ['not_delivered', 'requester_unreachable', 'payment_not_received', 'other'];
      var reason = preset ?? reasons.first;
      final ctrl = TextEditingController();
      return StatefulBuilder(builder: (ctx, setState) {
        final l = ctx.l10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.reportTitle, style: AppText.h2),
            const SizedBox(height: 14),
            Text(l.reportReason, style: AppText.smallBold),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(reasonLabelOf(ctx, r)),
                    selected: reason == r,
                    onSelected: (_) => setState(() => reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(hintText: l.reportDesc)),
            const SizedBox(height: 12),
            InfoBanner(l.reportNote, icon: Icons.shield_outlined),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => d.openDispute(t.id, reason, ctrl.text));
                Navigator.pop(ctx);
                showSnack(context, l.reportSent);
              },
              child: Text(l.submitReport),
            ),
          ],
        );
      });
    },
  );
}

String reasonLabelOf(BuildContext c, String key) {
  final l = c.l10n;
  return switch (key) {
    'space_occupied' => l.rSpaceOccupied,
    'not_delivered' => l.rNotDelivered,
    'payment_not_received' => l.rPaymentNotReceived,
    'requester_unreachable' => l.rUnreachable,
    _ => l.rOther,
  };
}

