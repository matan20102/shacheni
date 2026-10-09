import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/membership.dart';
import '../../data/providers.dart';

// Platform-admin screens against Supabase (P01, P02). Demo versions: platform_screens.dart.

/// P01 — buildings (counts only: the platform role sees no personal data).
class BackendPlatformScreen extends ConsumerStatefulWidget {
  const BackendPlatformScreen({super.key});

  @override
  ConsumerState<BackendPlatformScreen> createState() => _BackendPlatformScreenState();
}

class _BackendPlatformScreenState extends ConsumerState<BackendPlatformScreen> {
  late Future<List<Map<String, dynamic>>> _buildings = ref.read(membershipRepoProvider).platformBuildings();

  Future<void> _open(String route) async {
    await context.push(route);
    if (mounted) setState(() => _buildings = ref.read(membershipRepoProvider).platformBuildings());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.platformTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _buildings,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return PageBody(children: [InfoBanner(errorText(context, snap.error!), icon: Icons.cloud_off_rounded, tone: Tone.warn)]);
          }
          final buildings = snap.data!;
          return PageBody(children: [
            Text(l.buildingsTitle, style: AppText.h2),
            const SizedBox(height: 10),
            if (buildings.isEmpty) EmptyState(icon: Icons.apartment_rounded, title: l.noBuildingsYet),
            for (final b in buildings)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                onTap: () => _open(b['status'] == 'draft' ? '/platform/create?building=${b['id']}' : '/admin'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b['name'] as String, style: AppText.h3),
                              Text([b['address'], b['city']].whereType<String>().join(', '), style: AppText.small),
                            ],
                          ),
                        ),
                        StatusChip(
                          switch (b['status']) { 'active' => l.bActive, 'suspended' => l.bSuspended, _ => l.bDraft },
                          tone: b['status'] == 'active' ? Tone.success : Tone.warn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusChip(l.apartmentsCount('${b['apartments']}'), tone: Tone.neutral),
                      StatusChip(l.spacesCount('${b['spaces']}'), tone: Tone.neutral),
                      StatusChip(l.residentsCount('${b['residents']}'), tone: Tone.neutral),
                    ]),
                    if (b['status'] == 'draft') ...[
                      const SizedBox(height: 8),
                      Text(l.continueSetup, style: AppText.smallBold.copyWith(color: AppColors.primary)),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _open('/platform/create'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.createBuilding),
            ),
            const SizedBox(height: 12),
            InfoBanner(l.noAdminAppointNote, icon: Icons.admin_panel_settings_outlined),
          ]);
        },
      ),
    );
  }
}

/// P02 — create building: details → apartments → parking spaces → agreement & activate.
/// With [resumeId], continues a draft building created earlier (details are then fixed).
class BackendCreateBuildingScreen extends ConsumerStatefulWidget {
  const BackendCreateBuildingScreen({super.key, this.resumeId});
  final String? resumeId;

  @override
  ConsumerState<BackendCreateBuildingScreen> createState() => _BackendCreateBuildingScreenState();
}

class _BackendCreateBuildingScreenState extends ConsumerState<BackendCreateBuildingScreen> {
  int _step = 0;
  bool _accepted = false;
  bool _busy = false;
  bool _loading = false;
  String? _buildingId;
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _aptCount = TextEditingController();
  final _spaceCount = TextEditingController();
  final _apts = TextEditingController();
  final _spaces = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.resumeId != null) _resume(widget.resumeId!);
  }

  Future<void> _resume(String id) async {
    setState(() => _loading = true);
    try {
      final b = await ref.read(membershipRepoProvider).adminBuilding(id);
      _buildingId = id;
      _name.text = b['name'] as String;
      _address.text = b['address'] as String;
      _city.text = (b['city'] as String?) ?? '';
      _aptCount.text = '${b['declared_apartments']}';
      _spaceCount.text = '${b['declared_spaces']}';
      _apts.text = (b['apartments'] as List).join('\n');
      _spaces.text = (b['spaces'] as List).join('\n');
      _step = 1;
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _city, _aptCount, _spaceCount, _apts, _spaces]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<String> _parse(String text) =>
      text.split(RegExp(r'[\n,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  int get _declaredApts => int.tryParse(_aptCount.text.trim()) ?? 0;
  int get _declaredSpaces => int.tryParse(_spaceCount.text.trim()) ?? -1;

  bool get _stepValid => switch (_step) {
        0 => _name.text.trim().isNotEmpty && _address.text.trim().isNotEmpty && _declaredApts > 0 && _declaredSpaces >= 0,
        1 => _parse(_apts.text).length == _declaredApts,
        2 => _parse(_spaces.text).length == _declaredSpaces,
        _ => _accepted,
      };

  Future<void> _activate() async {
    final l = context.l10n;
    final repo = ref.read(membershipRepoProvider);
    setState(() => _busy = true);
    try {
      _buildingId ??= await repo.createBuilding(
          _name.text.trim(), _address.text.trim(), _city.text.trim(), _declaredApts, _declaredSpaces);
      await repo.setUnits(_buildingId!, _parse(_apts.text), _parse(_spaces.text));
      final code = await repo.activate(_buildingId!, ref.read(localeProvider).languageCode);
      await ref.read(gateProvider.notifier).refresh(); // you are now this building's admin
      if (!mounted) return;
      showSnack(context, l.buildingActivatedCode(code));
      context.pop();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _listStep({required bool apartments}) {
    final l = context.l10n;
    final ctrl = apartments ? _apts : _spaces;
    final declared = apartments ? _declaredApts : _declaredSpaces;
    final list = _parse(ctrl.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          color: AppColors.primarySoft,
          borderColor: AppColors.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(l.rangeGenerator, style: AppText.h3),
              ]),
              const SizedBox(height: 6),
              Text(apartments ? l.rangeApartmentsHint : l.rangeParkingHint, style: AppText.small),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: declared <= 0
                    ? null
                    : () => setState(() => ctrl.text =
                        [for (var i = 1; i <= declared; i++) apartments ? '$i' : 'P${i.toString().padLeft(2, '0')}'].join('\n')),
                icon: const Icon(Icons.format_list_numbered_rounded),
                label: Text(l.generateItems('$declared')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: ctrl,
            minLines: 6,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.pasteList, helperText: l.listHint, alignLabelWithHint: true),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Text(l.previewLabel, style: AppText.h3)),
            StatusChip(l.countMatch('${list.length}', '$declared'), tone: list.length == declared ? Tone.success : Tone.warn),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final s in list.take(60)) Chip(label: Text(s), visualDensity: VisualDensity.compact)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final steps = [l.stepDetails, l.stepApartments, l.stepParking, l.stepReview];
    final fixed = _buildingId != null; // created already: name/address/counts can no longer change

    final Widget body = switch (_step) {
      0 => Column(
          children: [
            TextField(controller: _name, enabled: !fixed, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.buildingName)),
            const SizedBox(height: 12),
            TextField(controller: _address, enabled: !fixed, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: l.buildingAddress)),
            const SizedBox(height: 12),
            TextField(controller: _city, enabled: !fixed, decoration: InputDecoration(labelText: l.cityLabel)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _aptCount,
                    enabled: !fixed,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l.apartmentCount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _spaceCount,
                    enabled: !fixed,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l.parkingCount),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            InfoBanner(l.noAdminAppointNote, icon: Icons.admin_panel_settings_outlined),
          ],
        ),
      1 => _listStep(apartments: true),
      2 => _listStep(apartments: false),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name.text, style: AppText.h2),
                  Text([_address.text, _city.text].where((s) => s.trim().isNotEmpty).join(', '), style: AppText.small),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    StatusChip(l.apartmentsCount('${_parse(_apts.text).length}'), tone: Tone.neutral),
                    StatusChip(l.spacesCount('${_parse(_spaces.text).length}'), tone: Tone.neutral),
                    StatusChip(l.bDraft, tone: Tone.warn),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.description_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.buildingAgreement, style: AppText.h3)),
                    TextButton(onPressed: () => context.push('/doc/agreement'), child: Text(l.legalRead)),
                  ]),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                    title: Text(l.legalAccept, style: AppText.body),
                  ),
                ],
              ),
            ),
          ],
        ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.createBuilding)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: StepperBar(labels: steps, current: _step),
          ),
          Expanded(child: PageBody(children: [body])),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(child: OutlinedButton(onPressed: _busy ? null : () => setState(() => _step--), child: Text(l.back))),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: !_stepValid || _busy ? null : (_step < 3 ? () => setState(() => _step++) : _activate),
                      child: _busy
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_step < 3 ? l.continueLabel : l.acceptActivate),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
