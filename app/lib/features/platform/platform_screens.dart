import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/providers.dart';
import 'backend_platform_screens.dart';

/// P01 — buildings (platform admin). In the pilot there is one building.
class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendPlatformScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    Widget check(String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: AppText.small.copyWith(color: AppColors.ink))),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l.platformTitle)),
      body: PageBody(
        children: [
          Text(l.buildingsTitle, style: AppText.h2),
          const SizedBox(height: 10),
          AppCard(
            onTap: () => context.push('/admin/settings'),
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
                          Text(d.buildingName.of(lang), style: AppText.h3),
                          Text(d.buildingAddress.of(lang), style: AppText.small),
                        ],
                      ),
                    ),
                    StatusChip(l.bActive, tone: Tone.success),
                  ],
                ),
                const Divider(height: 24),
                Text(l.checklistTitle, style: AppText.smallBold),
                const SizedBox(height: 6),
                check(l.chkApartments),
                check(l.chkSpaces),
                check(l.chkCounts),
                check(l.chkAgreement),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: StatusChip(l.apartmentsCount('${d.apartments.length}'), tone: Tone.neutral)),
                    const SizedBox(width: 6),
                    Expanded(child: StatusChip(l.spacesCount('${d.spaceLabels.length}'), tone: Tone.neutral)),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton(onPressed: () => showSnack(context, l.suspend), child: Text(l.suspend)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.push('/platform/create'),
            icon: const Icon(Icons.add_rounded),
            label: Text(l.createBuilding),
          ),
          const SizedBox(height: 12),
          InfoBanner(l.noAdminAppointNote, icon: Icons.admin_panel_settings_outlined),
        ],
      ),
    );
  }
}

/// P02 — create building wizard: details → apartments → parking spaces → review/activate.
class CreateBuildingScreen extends ConsumerStatefulWidget {
  const CreateBuildingScreen({super.key, this.resumeId});

  /// Real backend only: continue setting up this draft building.
  final String? resumeId;

  @override
  ConsumerState<CreateBuildingScreen> createState() => _CreateBuildingScreenState();
}

class _CreateBuildingScreenState extends ConsumerState<CreateBuildingScreen> {
  int _step = 0;
  bool _accepted = false;
  final _name = TextEditingController(text: 'Herzl 12');
  final _address = TextEditingController(text: '12 Herzl St');
  final _city = TextEditingController(text: 'Tel Aviv');
  final _apts = TextEditingController(text: '25');
  final _spaces = TextEditingController(text: '24');

  @override
  void dispose() {
    for (final c in [_name, _address, _city, _apts, _spaces]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return BackendCreateBuildingScreen(resumeId: widget.resumeId);
    final l = context.l10n;
    final steps = [l.stepDetails, l.stepApartments, l.stepParking, l.stepReview];
    final aptCount = int.tryParse(_apts.text) ?? 0;
    final spaceCount = int.tryParse(_spaces.text) ?? 0;

    Widget body;
    switch (_step) {
      case 0:
        body = Column(
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: l.buildingName)),
            const SizedBox(height: 12),
            TextField(controller: _address, decoration: InputDecoration(labelText: l.buildingAddress)),
            const SizedBox(height: 12),
            TextField(controller: _city, decoration: InputDecoration(labelText: l.cityLabel)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _apts,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: l.apartmentCount),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _spaces,
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
        );
      case 1:
      case 2:
        final isApt = _step == 1;
        final d = ref.read(demoProvider).data;
        final list = isApt ? d.apartments : d.spaceLabels;
        body = Column(
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
                  Text(isApt ? l.rangeApartmentsHint : l.rangeParkingHint, style: AppText.small),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.content_paste_rounded), label: Text(l.pasteList)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(l.previewLabel, style: AppText.h3)),
                StatusChip(l.countMatch('${list.length}', '${isApt ? aptCount : spaceCount}'),
                    tone: list.length == (isApt ? aptCount : spaceCount) ? Tone.success : Tone.warn),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in list.take(40)) Chip(label: Text(s), visualDensity: VisualDensity.compact)],
            ),
          ],
        );
      default:
        final d = ref.read(demoProvider).data;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name.text, style: AppText.h2),
                  Text('${_address.text}, ${_city.text}', style: AppText.small),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, children: [
                    StatusChip(l.apartmentsCount('${d.apartments.length}'), tone: Tone.neutral),
                    StatusChip(l.spacesCount('${d.spaceLabels.length}'), tone: Tone.neutral),
                    StatusChip(l.bDraft, tone: Tone.warn),
                  ]),
                ],
              ),
            ),
            SectionHeader(l.checklistTitle),
            for (final t in [l.chkApartments, l.chkSpaces, l.chkCounts])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text(t, style: AppText.body),
                ]),
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
        );
    }

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
                    Expanded(
                      child: OutlinedButton(onPressed: () => setState(() => _step--), child: Text(l.back)),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _step < 3
                          ? () => setState(() => _step++)
                          : (_accepted
                              ? () {
                                  showSnack(context, l.buildingActivated);
                                  context.pop();
                                }
                              : null),
                      child: Text(_step < 3 ? l.continueLabel : l.acceptActivate),
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
