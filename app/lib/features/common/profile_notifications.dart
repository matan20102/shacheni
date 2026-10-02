import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/status.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// S36 — public neighbor profile. Never shows apartment or phone (BR-K1).
class NeighborProfileScreen extends ConsumerWidget {
  const NeighborProfileScreen({super.key, required this.personId});
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final p = d.person(personId);
    final lang = context.lang;
    final reviews = <(String, String, int)>[
      ('נועה ר׳', 'Noa R.', 5),
      ('אמיר ק׳', 'Amir K.', 5),
      ('יוסי מ׳', 'Yossi M.', 4),
    ];
    final texts = <(String, String)>[
      ('מדויק, נעים וקל לתאם איתו.', 'Precise, pleasant and easy to coordinate with.'),
      ('הגיע בזמן והחבילה הייתה שלמה.', 'Arrived on time and the package was intact.'),
      ('חניה נקייה, תודה!', 'Clean space, thanks!'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.profileTitle)),
      body: PageBody(
        children: [
          Center(child: PersonAvatar(p, size: 92)),
          const SizedBox(height: 14),
          Center(child: Text(p.shortName(lang), style: AppText.h1)),
          const SizedBox(height: 6),
          Center(
            child: StatusChip(l.verifiedResident(d.buildingName.of(lang)), tone: Tone.success, icon: Icons.verified_rounded),
          ),
          const SizedBox(height: 18),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(p.isNew || p.rating == null ? '—' : p.rating!.toStringAsFixed(1), l.reviewsTitle,
                    icon: Icons.star_rounded, tail: p.isNew ? l.newNeighbor : '(${p.ratingCount})'),
                _Stat('${p.completed}', l.txCompleted),
                _Stat('${p.memberSince}', l.memberSince('').trim()),
              ],
            ),
          ),
          SectionHeader(l.reviewsTitle),
          if (p.isNew)
            Text(l.noReviews, style: AppText.small)
          else
            for (var i = 0; i < reviews.length; i++)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(lang == 'he' ? reviews[i].$1 : reviews[i].$2, style: AppText.bodyBold)),
                        StarRating(value: reviews[i].$3, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(lang == 'he' ? texts[i].$1 : texts[i].$2, style: AppText.body),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          InfoBanner(l.privateInfoNote, icon: Icons.lock_outline_rounded),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.icon, this.tail});
  final String value;
  final String label;
  final IconData? icon;
  final String? tail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 20, color: AppColors.accent),
            Text(value, style: AppText.h1),
          ],
        ),
        Text(tail ?? label, style: AppText.small),
      ],
    );
  }
}

/// S37 — notification center. Records hold type + params; text is rendered per language.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          TextButton(
            onPressed: () => ref.read(demoProvider.notifier).act((d) => d.markAllRead()),
            child: Text(l.markAllRead),
          ),
        ],
      ),
      body: d.notifications.isEmpty
          ? EmptyState(icon: Icons.notifications_none_rounded, title: l.allCaughtUp)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                for (final n in d.notifications) _NotificationTile(n),
              ],
            ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.n);
  final AppNotification n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(demoProvider).data;
    final r = renderNotification(context, n, d.person);
    final c = toneColors(r.tone);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: n.read ? AppColors.surface : AppColors.primarySoft.withValues(alpha: 0.55),
      onTap: () {
        ref.read(demoProvider.notifier).act((_) => n.read = true);
        if (n.route != null) context.push(n.route!);
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(13)),
            child: Icon(r.icon, color: c.fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.text, style: n.read ? AppText.body : AppText.bodyBold),
                Text(fmtAgo(context, n.time), style: AppText.tiny),
              ],
            ),
          ),
          if (!n.read)
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
