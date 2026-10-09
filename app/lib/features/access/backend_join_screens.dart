import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/membership.dart';
import '../../data/providers.dart';
import 'access_screens.dart';

// Join → apply → pending against Supabase (S05–S09). The demo versions live in access_screens.dart.

/// Shortcuts to the admin areas for an admin who is not (yet) an approved resident — the owner
/// sets up the building and approves their own application from here.
class _AdminShortcuts extends ConsumerWidget {
  const _AdminShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final access = ref.watch(myAccessProvider);
    if (access == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        if (access.isPlatformAdmin)
          TextButton.icon(
            onPressed: () => context.push('/platform'),
            icon: const Icon(Icons.domain_add_rounded, size: 18),
            label: Text(l.platformArea),
          ),
        if (access.isBuildingAdmin)
          TextButton.icon(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
            label: Text(l.adminArea),
          ),
      ],
    );
  }
}

/// S05 — find the building: by its join code, or by name / address (F37).
class BackendJoinScreen extends ConsumerStatefulWidget {
  const BackendJoinScreen({super.key});

  @override
  ConsumerState<BackendJoinScreen> createState() => _BackendJoinScreenState();
}

class _BackendJoinScreenState extends ConsumerState<BackendJoinScreen> {
  int _mode = 0; // 0 = by code · 1 = by address
  final _ctrl = TextEditingController();
  final _query = TextEditingController();
  List<({String id, String name, String address})>? _results;
  JoinInfo? _found;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(membershipRepoProvider).searchBuildings(_query.text.trim());
      setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(String buildingId) async {
    setState(() => _busy = true);
    try {
      final info = await ref.read(membershipRepoProvider).joinInfo(buildingId);
      setState(() => _found = info);
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _spinner() => const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));

  Future<void> _find() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final info = await ref.read(membershipRepoProvider).resolveJoinCode(_ctrl.text);
      setState(() {
        _found = info;
        _error = info == null ? l.joinInvalid : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final membership = ref.watch(myAccessProvider)?.membership;
    final found = _found;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const LanguageToggle(),
                  const Spacer(),
                  TextButton(onPressed: () => signOutEverywhere(ref), child: Text(l.logOut)),
                ],
              ),
              const SizedBox(height: 8),
              Text(l.joinTitle, style: AppText.h1),
              const SizedBox(height: 8),
              Text(l.joinSubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              if (membership?.status == 'rejected') ...[
                const SizedBox(height: 14),
                InfoBanner(l.previousRejected(membership?.statusReason ?? ''), icon: Icons.info_outline_rounded, tone: Tone.warn),
              ],
              const SizedBox(height: 18),
              PillTabs(
                labels: [l.joinByCode, l.joinByAddress],
                index: _mode,
                onChanged: (i) => setState(() {
                  _mode = i;
                  _found = null;
                  _error = null;
                }),
              ),
              const SizedBox(height: 16),
              if (found == null && _mode == 0) ...[
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.characters,
                    style: AppText.h2.copyWith(letterSpacing: 2),
                    decoration: InputDecoration(labelText: l.joinCodeLabel, errorText: _error),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _busy ? null : _find(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy || _ctrl.text.trim().isEmpty ? null : _find,
                  child: _busy ? _spinner() : Text(l.joinFind),
                ),
              ] else if (found == null) ...[
                TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l.searchBuildingHint,
                    errorText: _error,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: _busy || _query.text.trim().length < 2 ? null : _search,
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _busy || _query.text.trim().length < 2 ? null : _search(),
                ),
                const SizedBox(height: 12),
                if (_busy) Center(child: _spinner()),
                Expanded(
                  child: ListView(
                    children: [
                      if (_results != null && _results!.isEmpty && !_busy)
                        Text(l.searchNoResults, style: AppText.small),
                      for (final b in _results ?? const <({String id, String name, String address})>[])
                        AppCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          onTap: _busy ? null : () => _pick(b.id),
                          child: Row(
                            children: [
                              const Icon(Icons.apartment_rounded, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name, style: AppText.bodyBold),
                                    Text(b.address, style: AppText.small),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint, textDirection: Directionality.of(context)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ] else ...[
                Text(l.joinFound, style: AppText.small),
                const SizedBox(height: 8),
                AppCard(
                  color: AppColors.primarySoft,
                  borderColor: AppColors.primary,
                  child: Row(
                    children: [
                      const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(found.name, style: AppText.h2),
                            Text(found.address, style: AppText.small),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l.back,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _found = null),
                      ),
                    ],
                  ),
                ),
              ],
              if (found != null || _mode == 0) const Spacer(),
              const _AdminShortcuts(),
              if (found != null)
                FilledButton(
                  onPressed: () {
                    ref.read(joinInfoProvider.notifier).set(found);
                    context.go('/apply');
                  },
                  child: Text(l.joinConfirm),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// S06 — the application: name, phone, apartment, parking, declarations.
class BackendApplyScreen extends ConsumerStatefulWidget {
  const BackendApplyScreen({super.key});

  @override
  ConsumerState<BackendApplyScreen> createState() => _BackendApplyScreenState();
}

class _BackendApplyScreenState extends ConsumerState<BackendApplyScreen> {
  // Order matches decl1…decl5; keys are what submit_membership_application checks.
  static const _declKeys = ['accurate_info', 'is_resident', 'apartment_correct', 'parking_correct', 'rules_understood'];

  late final TextEditingController _name;
  late final TextEditingController _phone;
  ({String id, String label})? _apartment;
  final _spaceIds = <String>{};
  bool _noParking = false;
  final _decl = List<bool>.filled(5, false);
  bool _submitted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final access = ref.read(myAccessProvider);
    _name = TextEditingController(text: access?.fullName ?? '');
    _phone = TextEditingController(text: localPhone(access?.phone));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _hasParking => _spaceIds.isNotEmpty;
  bool get _phoneOk => _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9;
  bool get _declOk => _decl[0] && _decl[1] && _decl[2] && _decl[4] && (!_hasParking || _decl[3]);

  Future<void> _pickApartment(JoinInfo info) async {
    final picked = await showAppSheet<({String id, String label})>(
      context,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ctx.l10n.apartmentPick, style: AppText.h2),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in info.apartments)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _apartment?.id == a.id,
                  onSelected: (_) => Navigator.pop(ctx, a),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _apartment = picked);
  }

  Future<void> _submit(JoinInfo info) async {
    setState(() => _submitted = true);
    if (_name.text.trim().length < 2 || !_phoneOk || _apartment == null || !_declOk) return;
    setState(() => _busy = true);
    try {
      await ref.read(membershipRepoProvider).submitApplication(
            buildingId: info.buildingId,
            apartmentId: _apartment!.id,
            spaceIds: _spaceIds.toList(),
            fullName: _name.text.trim(),
            phone: _phone.text,
            declarations: {
              for (var i = 0; i < 5; i++)
                if (i != 3 || _hasParking) _declKeys[i]: _decl[i],
            },
            locale: ref.read(localeProvider).languageCode,
          );
      await ref.read(gateProvider.notifier).refresh(); // → pending
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final info = ref.watch(joinInfoProvider);
    if (info == null) {
      // reloaded the page mid-flow: the building has to be found again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/join');
      });
      return const LoadingScreen();
    }
    final decls = [l.decl1, l.decl2, l.decl3, l.decl4, l.decl5];

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.go('/join'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text(l.applyTitle, style: AppText.h1),
            const SizedBox(height: 6),
            Text('${info.name} · ${info.address}', style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 22),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.fullName,
                errorText: _submitted && _name.text.trim().length < 2 ? l.fieldRequired : null,
              ),
            ),
            const SizedBox(height: 14),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.phoneLabel,
                  hintText: '050-000-0000',
                  helperText: l.phoneHint,
                  errorText: _submitted && !_phoneOk ? l.phoneInvalid : null,
                ),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickApartment(info),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.apartment,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  errorText: _submitted && _apartment == null ? l.fieldRequired : null,
                ),
                child: Text(_apartment?.label ?? l.apartmentPick,
                    style: AppText.body.copyWith(color: _apartment == null ? AppColors.inkFaint : AppColors.ink)),
              ),
            ),
            if (info.spaces.isNotEmpty) ...[
              SectionHeader(l.parkingSpaces),
              Text(l.parkingOptionalHint, style: AppText.small),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in info.spaces)
                    FilterChip(
                      label: Text(s.label),
                      selected: _spaceIds.contains(s.id),
                      onSelected: (v) => setState(() {
                        v ? _spaceIds.add(s.id) : _spaceIds.remove(s.id);
                        if (v) _noParking = false;
                      }),
                    ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _noParking,
                onChanged: (v) => setState(() {
                  _noParking = v ?? false;
                  if (_noParking) _spaceIds.clear();
                }),
                title: Text(l.noParking, style: AppText.body),
              ),
            ],
            SectionHeader(l.declarationsTitle),
            for (var i = 0; i < 5; i++)
              if (i != 3 || _hasParking)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _decl[i],
                  onChanged: (v) => setState(() => _decl[i] = v ?? false),
                  title: Text(decls[i], style: AppText.body),
                  secondary: i == 4 ? TextButton(onPressed: () => context.push('/doc/rules'), child: Text(l.legalRead)) : null,
                ),
            if (_submitted && !_declOk) Text(l.fieldRequired, style: AppText.small.copyWith(color: AppColors.danger)),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : () => _submit(info),
              child: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.submitRequest),
            ),
          ],
        ),
      ),
    );
  }
}

/// S07/S08 — waiting for the admin; answer an info request; withdraw.
class BackendPendingScreen extends ConsumerStatefulWidget {
  const BackendPendingScreen({super.key});

  @override
  ConsumerState<BackendPendingScreen> createState() => _BackendPendingScreenState();
}

class _BackendPendingScreenState extends ConsumerState<BackendPendingScreen> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await ref.read(gateProvider.notifier).refresh();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final access = ref.watch(myAccessProvider);
    final m = access?.membership;
    if (access == null || m == null) return const LoadingScreen();
    final repo = ref.read(membershipRepoProvider);
    final open = m.status == 'pending' || m.status == 'info_requested';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Row(
              children: [
                const LanguageToggle(),
                const Spacer(),
                TextButton(onPressed: () => signOutEverywhere(ref), child: Text(l.logOut)),
              ],
            ),
            const HeroIllustration(icons: [Icons.hourglass_top_rounded, Icons.verified_user_rounded]),
            const SizedBox(height: 24),
            Text(l.pendingTitle(m.buildingName), style: AppText.h1),
            const SizedBox(height: 8),
            if (m.status == 'disabled')
              InfoBanner(l.membershipDisabled, icon: Icons.block_rounded, tone: Tone.danger)
            else
              Text(l.pendingBody, style: AppText.body.copyWith(color: AppColors.inkSoft)),
            if (m.status == 'info_requested') ...[
              const SizedBox(height: 16),
              AppCard(
                color: AppColors.accentSoft,
                borderColor: AppColors.accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.infoRequestFromAdmin, style: AppText.smallBold),
                    const SizedBox(height: 4),
                    Text(m.infoRequestMessage ?? '', style: AppText.body),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _reply,
                      maxLines: 3,
                      maxLength: 500,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: l.yourAnswer),
                    ),
                    FilledButton(
                      onPressed: _busy || _reply.text.trim().isEmpty
                          ? null
                          : () => _run(() => repo.respondToInfoRequest(_reply.text.trim())),
                      child: Text(l.send),
                    ),
                  ],
                ),
              ),
            ],
            SectionHeader(l.pendingSummary),
            AppCard(
              child: Column(
                children: [
                  KeyValueRow(l.nameLabel, access.fullName),
                  KeyValueRow(l.apartment, m.apartment),
                  if (m.spaces.isNotEmpty) KeyValueRow(l.parkingSpaces, m.spaces.map((s) => s.label).join(', ')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _AdminShortcuts(),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() async {}),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.checkStatus),
            ),
            if (open) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _busy ? null : () => _run(repo.withdrawApplication),
                child: Text(l.withdrawRequest),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
