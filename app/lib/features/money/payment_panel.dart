import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/status.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// S31 — the mock payment lifecycle. The app never processes or holds money; the payer
/// taps "I paid", the payee taps "Payment received" (PRD §11.8, BR-F2/F4).
class PaymentPanel extends ConsumerWidget {
  const PaymentPanel(this.txId, {super.key});
  final String txId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final t = d.txn(txId);
    if (t.amountMinor == 0) return const SizedBox.shrink();
    final iPay = t.payerId == DemoData.meId;
    final other = d.person(iPay ? t.payeeId : t.payerId);
    final otherName = other.shortName(context.lang);
    final amount = fmtAmount(t.amountMinor);
    final st = payStatusOf(context, t.pay);
    final act = ref.read(demoProvider.notifier).act;
    final live = t.status != TxStatus.cancelled;

    if (t.status == TxStatus.cancelled && !t.refundRecord) return const SizedBox.shrink();

    final children = <Widget>[];
    if (live) {
      if (iPay) {
        switch (t.pay) {
          case PaymentStatus.pending:
            children
              ..add(FilledButton(onPressed: () => act((d) => d.paymentMarkPaid(txId)), child: Text(l.iPaid)))
              ..add(DemoButton(l.demoPayeeConfirm(otherName), onPressed: () => act((d) {
                    d.paymentMarkPaid(txId);
                    d.paymentConfirmReceived(txId);
                  })));
          case PaymentStatus.payerConfirmed:
            children
              ..add(Row(children: [
                const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(child: Text(l.waitingConfirm(otherName), style: AppText.body)),
              ]))
              ..add(DemoButton(l.demoPayeeConfirm(otherName), onPressed: () => act((d) => d.paymentConfirmReceived(txId))));
          case PaymentStatus.settled:
            children.add(_Done(l.settledLabel, Tone.success));
          case PaymentStatus.cancelled:
            children.add(_Done(l.paymentCancelled, Tone.neutral));
        }
      } else {
        switch (t.pay) {
          case PaymentStatus.pending:
            children
              ..add(Row(children: [
                const Icon(Icons.hourglass_top_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(child: Text(l.waitingPay(otherName), style: AppText.body)),
              ]))
              ..add(const SizedBox(height: 10))
              ..add(OutlinedButton(
                  onPressed: () => act((d) => d.paymentWaive(txId)), child: Text(l.noPaymentNeeded)))
              ..add(DemoButton(l.demoPayerPaid(otherName), onPressed: () => act((d) => d.paymentMarkPaid(txId))));
          case PaymentStatus.payerConfirmed:
            children
              ..add(InfoBanner(l.saidPaid(amount, otherName), icon: Icons.payments_rounded, tone: Tone.info))
              ..add(const SizedBox(height: 12))
              ..add(FilledButton(onPressed: () => act((d) => d.paymentConfirmReceived(txId)), child: Text(l.paymentReceived)))
              ..add(const SizedBox(height: 8))
              ..add(OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                ),
                onPressed: () => act((d) => d.paymentNotReceived(txId)),
                child: Text(l.notReceived),
              ));
          case PaymentStatus.settled:
            children.add(_Done(l.settledLabel, Tone.success));
          case PaymentStatus.cancelled:
            children.add(_Done(l.paymentCancelled, Tone.neutral));
        }
      }
    }
    if (t.refundRecord) {
      children
        ..add(const SizedBox(height: 10))
        ..add(InfoBanner(l.refundRecord, icon: Icons.undo_rounded, tone: Tone.warn));
    }

    return AppCard(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(l.payTitle, style: AppText.h3)),
              StatusChip(st.label, tone: st.tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(iPay ? l.youPayTo(amount, otherName) : l.youReceiveFrom(amount, otherName), style: AppText.bodyBold),
          const SizedBox(height: 10),
          InfoBanner(l.paymentNotice, icon: Icons.shield_outlined),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done(this.text, this.tone);
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Row(
      children: [
        Icon(tone == Tone.success ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, color: c.fg),
        const SizedBox(width: 8),
        Text(text, style: AppText.bodyBold.copyWith(color: c.fg)),
      ],
    );
  }
}

