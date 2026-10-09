import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/membership.dart';

// Building-admin screens against Supabase (A01, A03, A04, A12). Demo versions: admin_screens.dart.
// MVP: the admin manages one building — the first in get_my_access.admin_buildings.

/// Loads a future once and reloads on demand; shows a spinner / error with retry.
class _Loader<T> extends StatelessWidget {
  const _Loader({required this.future, required this.onRetry, required this.builder});
  final Future<T>? future;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return PageBody(children: [
            InfoBanner(errorText(context, snap.error!), icon: Icons.cloud_off_rounded, tone: Tone.warn),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ]);
        }
        return builder(snap.data as T);
      },
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  final l = context.l10n;
  return switch (status) {
    'active' => l.bActive,
    'suspended' => l.bSuspended,
    _ => l.bDraft,
  };
}

/// A01 — dashboard.
class BackendAdminDashboard extends ConsumerStatefulWidget {
  const BackendAdminDashboard({super.key});

  @override
  ConsumerState<BackendAdminDashboard> createState() => _BackendAdminDashboardState();
}

class _BackendAdminDashboardState extends ConsumerState<BackendAdminDashboard> {
  Future<Map<String, dynamic>>? _building;

  void _load() {
    final id = ref.read(myAccessProvider)?.adminBuildingId;
    if (id != null) _building = ref.read(membershipRepoProvider).adminBuilding(id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminTitle)),
      body: _Loader<Map<String, dynamic>>(
        future: _building,
        onRetry: () => setState(_load),
        builder: (b) {
          final active = b['status'] == 'active';
          return PageBody(children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b['name'] as String, style: AppText.h3),
                        Text(b['address'] as String, style: AppText.small),
                      ],
                    ),
                  ),
                  StatusChip(_statusLabel(context, b['status'] as String), tone: active ? Tone.success : Tone.warn),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!active)
              FilledButton(
                onPressed: () => _open('/platform/create?building=${b['id']}'),
                child: Text(l.continueSetup),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      onTap: () => _open('/admin/applications'),
                      borderColor: (b['pending'] as num) > 0 ? AppColors.accent : AppColors.line,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.how_to_reg_rounded, color: AppColors.accent),
                          const SizedBox(height: 8),
                          Text('${b['pending']}', style: AppText.display),
                          Text(l.adminPendingApps, style: AppText.small),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.groups_rounded, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text('${b['residents']}', style: AppText.display),
                          Text(l.adminResidents, style: AppText.small),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppCard(
                onTap: () => _open('/admin/settings'),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded, color: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(child: Text(l.adminSettings, style: AppText.bodyMedium)),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('${b['join_code'] ?? ''}', style: AppText.bodyBold.copyWith(letterSpacing: 2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              InfoBanner(l.adminComingSoon, icon: Icons.construction_rounded),
            ],
          ]);
        },
      ),
    );
  }
}

/// A03 — join requests.
class BackendApplicationsScreen extends ConsumerStatefulWidget {
  const BackendApplicationsScreen({super.key});

  @override
  ConsumerState<BackendApplicationsScreen> createState() => _BackendApplicationsScreenState();
}

class _BackendApplicationsScreenState extends ConsumerState<BackendApplicationsScreen> {
  int _tab = 0;
  Future<List<AdminApplication>>? _apps;

  void _load() {
    final id = ref.read(myAccessProvider)?.adminBuildingId;
    if (id != null) _apps = ref.read(membershipRepoProvider).adminApplications(id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.applicationsTitle)),
      body: _Loader<List<AdminApplication>>(
        future: _apps,
        onRetry: () => setState(_load),
        builder: (all) {
          final items = all.where((a) => a.isOpen == (_tab == 0)).toList();
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _apps;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                PillTabs(labels: [l.tabPending, l.tabDecided], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                const SizedBox(height: 14),
                if (items.isEmpty) EmptyState(icon: Icons.how_to_reg_rounded, title: l.noPending),
                for (final a in items)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    borderColor: a.isSelf ? AppColors.accent : AppColors.line,
                    onTap: () async {
                      await context.push('/admin/applications/${a.id}');
                      if (mounted) setState(_load);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a.fullName, style: AppText.bodyBold)),
                            Text(fmtAgo(context, a.submittedAt), style: AppText.tiny),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l.apartmentLabel(a.apartment)}'
                          '${a.spaces.isEmpty ? '' : ' · ${a.spaces.map((s) => s.label).join(', ')}'}',
                          style: AppText.small,
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (a.isSelf) StatusChip(l.flagOwn, tone: Tone.accent, icon: Icons.person_pin_rounded),
                          if (a.secondResident) StatusChip(l.flagSecondResident, tone: Tone.info),
                          if (a.spaces.any((s) => s.heldByOther))
                            StatusChip(l.heldByOther, tone: Tone.warn, icon: Icons.warning_amber_rounded),
                          if (a.status == 'info_requested') StatusChip(l.infoRequested, tone: Tone.info),
                          if (!a.isOpen)
                            StatusChip(
                              a.status == 'approved' ? l.applicationApproved : l.applicationRejected,
                              tone: a.status == 'approved' ? Tone.success : Tone.danger,
                            ),
                        ]),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A04 — review one application.
class BackendApplicationReviewScreen extends ConsumerStatefulWidget {
  const BackendApplicationReviewScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BackendApplicationReviewScreen> createState() => _BackendApplicationReviewScreenState();
}

class _BackendApplicationReviewScreenState extends ConsumerState<BackendApplicationReviewScreen> {
  Future<AdminApplication?>? _app;
  Set<String>? _approveSpaces;
  bool _busy = false;

  void _load() {
    final buildingId = ref.read(myAccessProvider)?.adminBuildingId;
    if (buildingId == null) return;
    _app = ref.read(membershipRepoProvider).adminApplications(buildingId).then((all) {
      for (final a in all) {
        if (a.id == widget.id) return a;
      }
      return null;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _askNote(String title, String hint) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3, maxLength: 500, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(ctx.l10n.confirm)),
        ],
      ),
    ).whenComplete(ctrl.dispose);
  }

  Future<void> _decide(String decision, String done, {String? note, List<String> spaces = const []}) async {
    setState(() => _busy = true);
    try {
      await ref.read(membershipRepoProvider).decide(widget.id, decision, note: note, approveSpaceIds: spaces);
      // approving yourself changes your own access (→ resident)
      await ref.read(gateProvider.notifier).refresh();
      if (!mounted) return;
      showSnack(context, done);
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.reviewTitle2)),
      body: _Loader<AdminApplication?>(
        future: _app,
        onRetry: () => setState(_load),
        builder: (a) {
          if (a == null) return EmptyState(icon: Icons.search_off_rounded, title: l.noPending);
          final requested = a.spaces.where((s) => s.status == 'requested').toList();
          final approve = _approveSpaces ??= {for (final s in requested) if (!s.heldByOther) s.spaceId};
          return PageBody(children: [
            if (a.isSelf) ...[
              InfoBanner(l.selfReviewBanner, icon: Icons.person_pin_rounded, tone: Tone.accent),
              const SizedBox(height: 12),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyValueRow(l.nameLabel, a.fullName),
                  KeyValueRow(
                    l.phoneLabel,
                    '',
                    valueWidget: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Align(alignment: AlignmentDirectional.centerStart, child: SelectableText(a.phone, style: AppText.bodyMedium)),
                    ),
                  ),
                  KeyValueRow(l.apartment, a.apartment),
                  KeyValueRow(l.submittedAgo(fmtAgo(context, a.submittedAt)), ''),
                ],
              ),
            ),
            if (a.secondResident) ...[
              const SizedBox(height: 10),
              InfoBanner(l.flagSecondResident, icon: Icons.groups_rounded),
            ],
            if (a.infoRequestMessage != null) ...[
              const SizedBox(height: 10),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.infoRequested, style: AppText.smallBold),
                    Text(a.infoRequestMessage!, style: AppText.body),
                    if (a.infoResponse != null) ...[
                      const Divider(height: 18),
                      Text(l.yourAnswer, style: AppText.smallBold),
                      Text(a.infoResponse!, style: AppText.body),
                    ],
                  ],
                ),
              ),
            ],
            if (a.statusReason != null && !a.isOpen) ...[
              const SizedBox(height: 10),
              InfoBanner(a.statusReason!, icon: Icons.info_outline_rounded, tone: Tone.warn),
            ],
            if (a.spaces.isNotEmpty) ...[
              SectionHeader(l.requestedParking),
              if (a.spaces.any((s) => s.heldByOther)) InfoBanner(l.flagHeldByOther, icon: Icons.warning_amber_rounded, tone: Tone.warn),
              for (final s in a.spaces)
                if (s.status == 'requested' && a.isOpen)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: approve.contains(s.spaceId),
                    onChanged: (v) => setState(() => v == true ? approve.add(s.spaceId) : approve.remove(s.spaceId)),
                    title: Text(l.alsoApproveParking(s.label)),
                  )
                else
                  KeyValueRow(s.label, s.status == 'active' ? l.applicationApproved : l.applicationRejected),
            ],
            const SizedBox(height: 18),
            if (a.isOpen) ...[
              FilledButton(
                onPressed: _busy ? null : () => _decide('approve', l.applicationApproved, spaces: approve.toList()),
                child: Text(l.approveApplication),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final note = await _askNote(l.requestInfo, l.questionHint);
                        if (note != null && note.isNotEmpty) await _decide('request_info', l.infoRequested, note: note);
                      },
                child: Text(l.requestInfo),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.4),
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        final note = await _askNote(l.rejectApplication, l.reasonHint);
                        if (note != null && note.isNotEmpty) await _decide('reject', l.applicationRejected, note: note);
                      },
                child: Text(l.rejectApplication),
              ),
            ],
          ]);
        },
      ),
    );
  }
}

/// A12 — building settings: join code and the poster to hang in the lobby.
class BackendBuildingSettingsScreen extends ConsumerStatefulWidget {
  const BackendBuildingSettingsScreen({super.key});

  @override
  ConsumerState<BackendBuildingSettingsScreen> createState() => _BackendBuildingSettingsScreenState();
}

class _BackendBuildingSettingsScreenState extends ConsumerState<BackendBuildingSettingsScreen> {
  Future<Map<String, dynamic>>? _building;

  void _load() {
    final id = ref.read(myAccessProvider)?.adminBuildingId;
    if (id != null) _building = ref.read(membershipRepoProvider).adminBuilding(id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminSettings)),
      body: _Loader<Map<String, dynamic>>(
        future: _building,
        onRetry: () => setState(_load),
        builder: (b) {
          final code = (b['join_code'] as String?) ?? '—';
          final name = b['name'] as String;
          return PageBody(children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.buildingInfo, style: AppText.h3),
                  const SizedBox(height: 8),
                  Text(name, style: AppText.bodyBold),
                  Text([b['address'], b['city']].whereType<String>().join(', '), style: AppText.small),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusChip(l.apartmentsCount('${(b['apartments'] as List).length}'), tone: Tone.neutral),
                    StatusChip(l.spacesCount('${(b['spaces'] as List).length}'), tone: Tone.neutral),
                    StatusChip(l.residentsCount('${b['residents']}'), tone: Tone.neutral),
                    StatusChip(_statusLabel(context, b['status'] as String),
                        tone: b['status'] == 'active' ? Tone.success : Tone.warn),
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
                    child: SelectableText(code, style: AppText.display.copyWith(letterSpacing: 3, color: AppColors.primary)),
                  ),
                  const SizedBox(height: 8),
                  Text(l.joinCodeHint, style: AppText.small, textAlign: TextAlign.center),
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
                  Text(l.posterBody(name), style: AppText.body.copyWith(color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(code, style: AppText.h1.copyWith(letterSpacing: 3, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: b['allow_admin_self_review'] as bool,
                onChanged: null, // platform-admin setting; changed by SQL for now
                title: Text(l.selfReviewSwitch, style: AppText.bodyMedium),
                subtitle: Text(l.selfReviewHint, style: AppText.tiny),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
