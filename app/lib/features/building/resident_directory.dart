import 'package:flutter/material.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/resident_directory_model.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';

class BuildingManagementSheet extends StatelessWidget {
  const BuildingManagementSheet({
    super.key,
    required this.vm,
    required this.buildingId,
    required this.onLeave,
    required this.onArchive,
  });
  final BuildingViewModel vm;
  final String buildingId;
  final void Function(BuildContext, BuildingHome) onLeave, onArchive;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final home = vm.homes.where((h) => h.id == buildingId).firstOrNull;
      if (home == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('הבניין אינו זמין כעת.'),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'מידע וניהול הבניין',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    home.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (home.address != home.name) Text(home.address),
                  const SizedBox(height: 8),
                  Text(
                    'דירה ${home.apartment}${home.householdName.isEmpty ? '' : ' · ${home.householdName}'}',
                  ),
                  const SizedBox(height: 8),
                  SoftTag(
                    home.isAdmin ? 'מנהל בניין' : 'דייר בבניין',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ResidentDirectory(
              key: ValueKey(buildingId),
              vm: vm,
              buildingId: buildingId,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('building-leave'),
              onPressed: vm.busy ? null : () => onLeave(context, home),
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('יציאה מהבניין'),
            ),
            if (home.isAdmin) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                key: const Key('building-archive'),
                onPressed: vm.busy ? null : () => onArchive(context, home),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('ארכוב הבניין'),
              ),
              const SizedBox(height: 8),
              const Text(
                'ארכוב סוגר את הבניין לפעילות ולהצטרפות ושומר את ההיסטוריה.',
                style: TextStyle(color: glassMuted),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class ResidentDirectory extends StatefulWidget {
  const ResidentDirectory({
    super.key,
    required this.vm,
    required this.buildingId,
  });
  final BuildingViewModel vm;
  final String buildingId;
  @override
  State<ResidentDirectory> createState() => _ResidentDirectoryState();
}

class _ResidentDirectoryState extends State<ResidentDirectory> {
  late final model = ResidentDirectoryModel(widget.vm, widget.buildingId)
    ..load();
  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<void> person(ResidentMember member) async {
    final promote = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        final admin = widget.vm.homes.any(
          (h) => h.id == widget.buildingId && h.isAdmin,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name, style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'דירה ${member.apartment}${member.household.isEmpty ? '' : ' · ${member.household}'}',
              ),
              const SizedBox(height: 16),
              if (member.isApartmentAdmin)
                const SoftTag('מנהל הדירה', icon: Icons.home_outlined),
              if (member.isAdmin)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SoftTag(
                    'מנהל בניין',
                    icon: Icons.verified_user_outlined,
                  ),
                ),
              if (admin) ...[
                const SizedBox(height: 24),
                Text(
                  member.isAdmin
                      ? 'אפשר להסיר את הרשאת ניהול הבניין. החברות בבניין נשמרת.'
                      : 'מנהל בניין יכול לאשר הצטרפות, למנות מנהלים ולארכב את הבניין.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('resident-change-role'),
                  onPressed: () => Navigator.pop(ctx, !member.isAdmin),
                  child: Text(
                    member.isAdmin
                        ? 'הסרת הרשאת מנהל בניין'
                        : 'מינוי למנהל בניין',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (promote == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          promote
              ? 'למנות את ${member.name} למנהל בניין?'
              : 'להסיר את הרשאת הניהול של ${member.name}?',
        ),
        content: const Text(
          'השינוי נוגע לניהול הבניין. תפקיד מנהל הדירה נשמר.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('resident-confirm-role'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('אישור השינוי'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await model.changeRole(member, promote);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final groups = <String, List<ResidentMember>>{};
      for (final member in model.members) {
        (groups[member.apartment] ??= []).add(member);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('השכנים בבניין', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'מסודרים לפי דירה · מנהל הבית מופיע ראשון',
            style: TextStyle(color: glassMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (model.loading || model.saving) const LinearProgressIndicator(),
          if (model.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buildingErrorMessage(model.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: model.saving ? null : model.load,
                    child: const Text('ניסיון נוסף'),
                  ),
                ],
              ),
            ),
          for (final entry in groups.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'דירה ${entry.key}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: glassTeal,
                      ),
                    ),
                    for (final member in entry.value)
                      ListTile(
                        key: ValueKey('resident-${member.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE0F0EE),
                          child: Text(
                            member.name.isEmpty
                                ? 'ש'
                                : member.name.characters.first,
                          ),
                        ),
                        title: Text(
                          '${member.name}${member.mine ? ' (אני)' : ''}',
                        ),
                        subtitle: member.isApartmentAdmin || member.isAdmin
                            ? Text(
                                [
                                  if (member.isApartmentAdmin) 'מנהל הדירה',
                                  if (member.isAdmin) 'מנהל בניין',
                                ].join(' · '),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.chevron_left_rounded,
                          size: 18,
                        ),
                        onTap: model.saving ? null : () => person(member),
                      ),
                  ],
                ),
              ),
            ),
          if (!model.loading && model.error == null && model.members.isEmpty)
            const Text('אין כרגע דיירים להצגה.'),
        ],
      );
    },
  );
}
