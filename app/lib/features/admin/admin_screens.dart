import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/status.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/auth.dart';
import '../../data/providers.dart';
import 'backend_admin_screens.dart';
import '../packages/door_delivery.dart' show SamplePhoto;

/// A01 — admin dashboard (building admin; in the pilot that is you).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendAdminDashboard();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final openDisputes = d.disputes.where((x) => !x.resolved).length;
    final assignReq = d.assignmentRequests.where((a) => a.status == AssignmentStatus.requested).length;

    Widget tile(IconData icon, String label, String value, Color color, Color bg, String route, {bool alert = false}) => AppCard(
          onTap: () => context.push(route),
          borderColor: alert ? AppColors.danger : AppColors.line,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              Text(value, style: AppText.display),
              Text(label, style: AppText.small, maxLines: 2),
            ],
          ),
        );

    Widget link(IconData icon, String label, String route) => AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          onTap: () => context.push(route),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppText.bodyMedium)),
              Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint, textDirection: Directionality.of(context)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.adminTitle)),
      body: PageBody(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              tile(Icons.how_to_reg_rounded, l.adminPendingApps, '${d.pendingApplicationCount}', AppColors.accent,
                  AppColors.accentSoft, '/admin/applications'),
              tile(Icons.local_parking_rounded, l.adminParkingRequests, '$assignReq', AppColors.primary,
                  AppColors.primarySoft, '/admin/assignments'),
              tile(Icons.gavel_rounded, l.adminDisputes, '$openDisputes', AppColors.danger, AppColors.dangerSoft,
                  '/admin/disputes', alert: openDisputes > 0),
              tile(Icons.insights_rounded, l.adminStats, '${d.txns.length}', AppColors.info, AppColors.infoSoft, '/admin/stats'),
            ],
          ),
          const SizedBox(height: 18),
          link(Icons.groups_rounded, l.adminResidents, '/admin/residents'),
          link(Icons.apartment_rounded, l.adminApartments, '/admin/apartments'),
          link(Icons.local_parking_rounded, l.adminSpaces, '/admin/spaces'),
          link(Icons.view_list_rounded, l.adminActivity, '/admin/activity'),
          link(Icons.settings_rounded, l.adminSettings, '/admin/settings'),
        ],
      ),
    );
  }
}

/// A03 — join requests.
class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendApplicationsScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final items = d.applications.where((a) => (a.status == ApplicationStatus.pending || a.status == ApplicationStatus.infoRequested) == (_tab == 0)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(l.applicationsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          PillTabs(labels: [l.tabPending, l.tabDecided], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 14),
          if (items.isEmpty) EmptyState(icon: Icons.how_to_reg_rounded, title: l.noPending),
          for (final a in items)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              borderColor: a.isMine ? AppColors.accent : AppColors.line,
              onTap: () => context.push('/admin/applications/${a.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(a.name.of(lang), style: AppText.bodyBold)),
                      Text(fmtAgo(context, a.submittedAt), style: AppText.tiny),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${l.apartmentLabel(a.apartment)}${a.spaces.isEmpty ? '' : ' · ${a.spaces.join(', ')}'}', style: AppText.small),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (a.isMine) StatusChip(l.flagOwn, tone: Tone.accent, icon: Icons.person_pin_rounded),
                    if (a.secondResident) StatusChip(l.flagSecondResident, tone: Tone.info),
                    if (a.spaceHeldByOther) StatusChip(l.heldByOther, tone: Tone.warn, icon: Icons.warning_amber_rounded),
                    if (_tab == 1)
                      StatusChip(
                        a.status == ApplicationStatus.approved ? l.applicationApproved : l.applicationRejected,
                        tone: a.status == ApplicationStatus.approved ? Tone.success : Tone.danger,
                      ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A04 — review one application: approve / reject / request more info.
class ApplicationReviewScreen extends ConsumerStatefulWidget {
  const ApplicationReviewScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ApplicationReviewScreen> createState() => _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends ConsumerState<ApplicationReviewScreen> {
  final _approveSpaces = <String>{};
  bool _init = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return BackendApplicationReviewScreen(id: widget.id);
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final a = d.applications.firstWhere((x) => x.id == widget.id);
    final lang = context.lang;
    if (!_init) {
      _approveSpaces.addAll(a.spaces);
      _init = true;
    }
    final open = a.status == ApplicationStatus.pending || a.status == ApplicationStatus.infoRequested;

    return Scaffold(
      appBar: AppBar(title: Text(l.reviewTitle2)),
      body: PageBody(
        children: [
          if (a.isMine) ...[
            InfoBanner(l.selfReviewBanner, icon: Icons.person_pin_rounded, tone: Tone.accent),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KeyValueRow(l.nameLabel, a.name.of(lang)),
                KeyValueRow(l.phoneLabel, '', valueWidget: Directionality(textDirection: TextDirection.ltr, child: Align(alignment: AlignmentDirectional.centerStart, child: Text(a.phone, style: AppText.bodyMedium)))),
                KeyValueRow(l.apartment, a.apartment),
                KeyValueRow(l.submittedAgo(fmtAgo(context, a.submittedAt)), ''),
              ],
            ),
          ),
          if (a.secondResident) ...[
            const SizedBox(height: 10),
            InfoBanner(l.flagSecondResident, icon: Icons.groups_rounded),
          ],
          if (a.spaces.isNotEmpty) ...[
            SectionHeader(l.requestedParking),
            if (a.spaceHeldByOther) InfoBanner(l.flagHeldByOther, icon: Icons.warning_amber_rounded, tone: Tone.warn),
            for (final s in a.spaces)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _approveSpaces.contains(s),
                onChanged: open ? (v) => setState(() => v == true ? _approveSpaces.add(s) : _approveSpaces.remove(s)) : null,
                title: Text(l.alsoApproveParking(s)),
              ),
          ],
          const SizedBox(height: 18),
          if (open) ...[
            FilledButton(
              onPressed: () {
                final ok = ref.read(demoProvider.notifier);
                late bool allowed;
                ok.act((d) => allowed = d.decideApplication(a.id, ApplicationStatus.approved));
                if (allowed) {
                  showSnack(context, l.applicationApproved);
                  context.pop();
                }
              },
              child: Text(l.approveApplication),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => a.status = ApplicationStatus.infoRequested);
                showSnack(context, l.infoRequested);
              },
              child: Text(l.requestInfo),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => d.decideApplication(a.id, ApplicationStatus.rejected));
                showSnack(context, l.applicationRejected);
                context.pop();
              },
              child: Text(l.rejectApplication),
            ),
          ],
        ],
      ),
    );
  }
}

/// A08 — parking assignment requests and active assignments.
class AssignmentsAdminScreen extends ConsumerStatefulWidget {
  const AssignmentsAdminScreen({super.key});

  @override
  ConsumerState<AssignmentsAdminScreen> createState() => _AssignmentsAdminScreenState();
}

class _AssignmentsAdminScreenState extends ConsumerState<AssignmentsAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final reqs = d.assignmentRequests.where((a) => a.status == AssignmentStatus.requested).toList();
    final active = <AssignmentRequestItem>[
      ...d.assignmentRequests.where((a) => a.status == AssignmentStatus.active),
      AssignmentRequestItem(id: 'x1', residentName: const Bi('דנה כהן', 'Dana Cohen'), apartment: '403', spaceLabel: 'P07', status: AssignmentStatus.active),
      AssignmentRequestItem(id: 'x2', residentName: const Bi('רינה שלום', 'Rina Shalom'), apartment: '506', spaceLabel: 'P12', status: AssignmentStatus.active),
      AssignmentRequestItem(id: 'x3', residentName: const Bi('מתן לוי', 'Matan Levy'), apartment: '12', spaceLabel: 'P03', isMine: true, status: AssignmentStatus.active),
    ];
    final items = _tab == 0 ? reqs : active;
    return Scaffold(
      appBar: AppBar(title: Text(l.assignmentsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          PillTabs(labels: [l.tabRequests, l.tabActive], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 14),
          if (items.isEmpty) EmptyState(icon: Icons.local_parking_rounded, title: l.noPending),
          for (final a in items)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              borderColor: a.isMine ? AppColors.accent : AppColors.line,
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
                        child: Text(a.spaceLabel, style: AppText.h3.copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.residentName.of(lang), style: AppText.bodyBold),
                            Text(l.apartmentLabel(a.apartment), style: AppText.small),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (a.isMine || a.heldByOther) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (a.isMine) StatusChip(l.flagOwn, tone: Tone.accent, icon: Icons.person_pin_rounded),
                      if (a.heldByOther) StatusChip(l.heldByOther, tone: Tone.warn, icon: Icons.warning_amber_rounded),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  if (_tab == 0)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(demoProvider.notifier).act((d) => d.decideAssignment(a.id, false));
                              showSnack(context, l.assignmentRejected);
                            },
                            child: Text(l.reject),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: a.heldByOther
                                ? null
                                : () {
                                    ref.read(demoProvider.notifier).act((d) => d.decideAssignment(a.id, true));
                                    showSnack(context, l.assignmentApproved);
                                  },
                            child: Text(l.approve),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton(onPressed: () => showSnack(context, l.endAssignment), child: Text(l.endAssignment)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A10 — disputes.
class DisputesScreen extends ConsumerWidget {
  const DisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      appBar: AppBar(title: Text(l.disputesTitle)),
      body: d.disputes.isEmpty
          ? EmptyState(icon: Icons.gavel_rounded, title: l.noDisputes)
          : PageBody(
              children: [
                for (final x in d.disputes)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(reasonLabel(context, x.reasonKey), style: AppText.bodyBold)),
                            StatusChip(x.resolved ? l.resolvedChip : l.openChip, tone: x.resolved ? Tone.success : Tone.danger),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (x.description.isNotEmpty) Text(x.description, style: AppText.body),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final t = d.txn(x.txId);
                          final party = t.payerId == DemoData.meId || t.payeeId == DemoData.meId;
                          final isDoor = t.type == TxType.delivery && d.request(t.refId).handoffMethod == HandoffMethod.doorPhoto;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (party) InfoBanner(l.youArePartyNote, icon: Icons.person_pin_rounded, tone: Tone.accent),
                              if (isDoor) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: const SizedBox(height: 110, width: double.infinity, child: SamplePhoto()),
                                ),
                              ],
                            ],
                          );
                        }),
                        if (!x.resolved) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: () => _resolve(context, ref, x), child: Text(l.resolve)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  void _resolve(BuildContext context, WidgetRef ref, Dispute x) {
    var delivered = true;
    showAppSheet<void>(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final l = ctx.l10n;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.resolve, style: AppText.h2),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: delivered,
              onChanged: (v) => setState(() => delivered = v),
              title: Text(l.serviceDelivered),
            ),
            TextField(maxLines: 3, decoration: InputDecoration(labelText: l.resolutionNote)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => d.resolveDispute(x.id));
                Navigator.pop(ctx);
              },
              child: Text(l.confirm),
            ),
          ],
        );
      });
    });
  }
}

/// A11 — statistics.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final doneParking = d.txns.where((t) => t.type == TxType.parking && t.status == TxStatus.completed).length;
    final donePickup = d.txns.where((t) => t.type == TxType.delivery && t.status == TxStatus.completed).length;
    final closed = d.txns.where((t) => t.status == TxStatus.completed || t.status == TxStatus.cancelled).length;
    final completion = closed == 0 ? 0 : ((d.txns.where((t) => t.status == TxStatus.completed).length / closed) * 100).round();
    final stats = <(String, String)>[
      (l.statApartments, '${d.apartments.length}'),
      (l.statResidents, '${d.people.length}'),
      (l.statActiveWeek, '5'),
      (l.statListings, '${d.listings.length}'),
      (l.statReservations, '${d.reservations.length}'),
      (l.statRequests, '${d.requests.length}'),
      (l.statDoneParking, '$doneParking'),
      (l.statDonePickup, '$donePickup'),
      (l.statCompletion, '$completion%'),
      (l.statRating, '4.8'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.statsTitle)),
      body: PageBody(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              for (final s in stats)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.$2, style: AppText.h1.copyWith(color: AppColors.primary)),
                      Text(s.$1, style: AppText.small, maxLines: 2),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A09 — building activity (listings · packages · transactions). No secrets are shown.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final rows = <Widget>[];
    if (_tab == 0) {
      for (final x in d.listings) {
        final st = listingStatusOf(context, x.status);
        rows.add(_row(l.parkingLabel(x.spaceLabel), '${d.person(x.ownerId).shortName(lang)} · ${fmtWindow(context, x.start, x.end)}', fmtMoney(x.priceMinor), st));
      }
    } else if (_tab == 1) {
      for (final x in d.requests) {
        final st = requestStatusOf(context, x.status);
        rows.add(_row(x.location.of(lang), '${d.person(x.requesterId).shortName(lang)} · ${l.untilTime(fmtDayTime(context, x.deadline))}', fmtMoney(x.rewardMinor), st));
      }
    } else {
      for (final t in d.txns) {
        final st = txStatusOf(context, t.status);
        rows.add(_row(t.type == TxType.parking ? l.parkingLabel(t.title.of(lang)) : t.title.of(lang),
            '${d.person(t.payerId).shortName(lang)} → ${d.person(t.payeeId).shortName(lang)}', fmtMoney(t.amountMinor), st));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.activityTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          PillTabs(labels: [l.tabListings, l.tabPackages, l.tabTransactions], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String title, String sub, String amount, Status st) => AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(sub, style: AppText.small, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: AppText.bodyBold),
                const SizedBox(height: 4),
                StatusChip(st.label, tone: st.tone),
              ],
            ),
          ],
        ),
      );
}

/// A05 — residents (read-only list for the prototype).
class ResidentsScreen extends ConsumerWidget {
  const ResidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminResidents)),
      body: PageBody(
        children: [
          for (final p in d.people.values)
            AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: PersonLine(
                p,
                subtitle: Text('${l.apartmentLabel(p.apartment)} · ${p.phone}', style: AppText.small),
                trailing: StatusChip(l.statusActive, tone: Tone.success),
              ),
            ),
        ],
      ),
    );
  }
}

/// A06 / A07 — apartment and parking-space lists (authoritative building data).
class BuildingListScreen extends ConsumerWidget {
  const BuildingListScreen({super.key, required this.spaces});
  final bool spaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final items = spaces ? d.spaceLabels : d.apartments;
    final held = {for (final a in d.assignments.where((a) => a.status == AssignmentStatus.active)) a.spaceLabel, 'P07', 'P12', 'P21'};
    return Scaffold(
      appBar: AppBar(title: Text(spaces ? l.adminSpaces : l.adminApartments)),
      body: PageBody(
        children: [
          StatusChip(spaces ? l.spacesCount('${items.length}') : l.apartmentsCount('${items.length}'), tone: Tone.success, icon: Icons.check_rounded),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in items)
                Chip(
                  label: Text(s),
                  backgroundColor: spaces && held.contains(s) ? AppColors.primarySoft : AppColors.surface,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A12 — building settings: join code, printable poster, self-review switch.
class BuildingSettingsScreen extends ConsumerWidget {
  const BuildingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendBuildingSettingsScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminSettings)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.buildingInfo, style: AppText.h3),
                const SizedBox(height: 8),
                Text(d.buildingName.of(lang), style: AppText.bodyBold),
                Text(d.buildingAddress.of(lang), style: AppText.small),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  StatusChip(l.apartmentsCount('${d.apartments.length}'), tone: Tone.neutral),
                  StatusChip(l.spacesCount('${d.spaceLabels.length}'), tone: Tone.neutral),
                  StatusChip(l.bActive, tone: Tone.success),
                ]),
              ],
            ),
          ),
          SectionHeader(l.joinCodeTitle),
          AppCard(
            child: Column(
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(d.joinCodeValue, style: AppText.display.copyWith(letterSpacing: 3, color: AppColors.primary)),
                ),
                const SizedBox(height: 8),
                Text(l.joinCodeHint, style: AppText.small, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    ref.read(demoProvider.notifier).act((d) => d.joinCodeValue = 'SHACH-${(10 + (DateTime.now().millisecond % 89))}');
                  },
                  child: Text(l.rotateCode),
                ),
              ],
            ),
          ),
          SectionHeader(l.posterTitle),
          AppCard(
            color: AppColors.primary,
            borderColor: AppColors.primary,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Icon(Icons.home_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 6),
                Text(l.appName, style: AppText.display.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text(l.posterBody(d.buildingName.of(lang)), style: AppText.body.copyWith(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(d.joinCodeValue, style: AppText.h1.copyWith(letterSpacing: 3, color: AppColors.primary)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: d.selfReviewAllowed,
              onChanged: (v) => ref.read(demoProvider.notifier).act((d) => d.selfReviewAllowed = v),
              title: Text(l.selfReviewSwitch, style: AppText.bodyMedium),
              subtitle: Text(l.selfReviewHint, style: AppText.tiny),
            ),
          ),
        ],
      ),
    );
  }
}
