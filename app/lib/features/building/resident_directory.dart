import 'package:flutter/material.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/resident_directory_model.dart';
import '../../data/building/supabase_building_repository.dart';
import 'board_reports.dart';
import 'glass_widgets.dart';
import 'invite_qr.dart';

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
            const SizedBox(height: Space.xl),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    home.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (home.address != home.name) Text(home.address),
                  const SizedBox(height: Space.s),
                  Text(
                    'דירה ${home.apartment}${home.householdName.isEmpty ? '' : ' · ${home.householdName}'}',
                  ),
                  const SizedBox(height: Space.s),
                  SoftTag(
                    home.isAdmin ? 'מנהל בניין' : 'דייר בבניין',
                    icon: Icons.verified_user_outlined,
                  ),
                ],
              ),
            ),
            if (home.code.isNotEmpty) ...[
              const SizedBox(height: Space.l),
              InviteQrPanel(
                key: ValueKey('invite-qr-$buildingId'),
                name: home.name,
                code: home.code,
              ),
            ],
            const SizedBox(height: Space.xxl),
            ResidentDirectory(
              key: ValueKey(buildingId),
              vm: vm,
              buildingId: buildingId,
            ),
            if (home.isAdmin)
              BoardReportsPanel(
                key: ValueKey('reports-$buildingId'),
                vm: vm,
                buildingId: buildingId,
              ),
            const SizedBox(height: Space.xxl),
            OutlinedButton.icon(
              key: const Key('building-leave'),
              onPressed: vm.busy ? null : () => onLeave(context, home),
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('יציאה מהבניין'),
            ),
            if (home.isAdmin) ...[
              const SizedBox(height: Space.m),
              TextButton.icon(
                key: const Key('building-archive'),
                onPressed: vm.busy ? null : () => onArchive(context, home),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('ארכוב הבניין'),
              ),
              const SizedBox(height: Space.s),
              Text(
                'ארכוב סוגר את הבניין לפעילות ולהצטרפות ושומר את ההיסטוריה.',
                style: TextStyle(color: context.glass.muted),
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
    final action = await showModalBottomSheet<String>(
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
              const SizedBox(height: Space.s),
              Text(
                'דירה ${member.apartment}${member.household.isEmpty ? '' : ' · ${member.household}'}',
              ),
              const SizedBox(height: Space.l),
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
                const SizedBox(height: Space.xxl),
                Text(
                  member.isAdmin
                      ? 'אפשר להסיר את הרשאת ניהול הבניין. החברות בבניין נשמרת.'
                      : 'מנהל בניין יכול לאשר הצטרפות, למנות מנהלים ולארכב את הבניין.',
                ),
                const SizedBox(height: Space.l),
                FilledButton(
                  key: const Key('resident-change-role'),
                  onPressed: () =>
                      Navigator.pop(ctx, member.isAdmin ? 'demote' : 'promote'),
                  child: Text(
                    member.isAdmin
                        ? 'הסרת הרשאת מנהל בניין'
                        : 'מינוי למנהל בניין',
                  ),
                ),
                if (!member.mine && !member.isAdmin) ...[
                  const SizedBox(height: Space.s),
                  TextButton.icon(
                    key: const Key('resident-remove'),
                    onPressed: () => Navigator.pop(ctx, 'remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.glass.error,
                    ),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('הסרה מהבניין'),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    final promote = action == 'promote';
    final remove = action == 'remove';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          remove
              ? 'להסיר את ${member.name} מהבניין?'
              : promote
              ? 'למנות את ${member.name} למנהל בניין?'
              : 'להסיר את הרשאת הניהול של ${member.name}?',
        ),
        content: Text(
          remove
              ? 'הגישה ללוח, לדיירים ולחניון תיסגר, והזמנות חניה עתידיות יבוטלו. כדי לחזור תידרש בקשת הצטרפות חדשה.'
              : 'השינוי נוגע לניהול הבניין. תפקיד מנהל הדירה נשמר.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('resident-confirm-role'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(remove ? 'הסרה מהבניין' : 'אישור השינוי'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (remove) {
      await model.remove(member);
    } else {
      await model.changeRole(member, promote);
    }
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
          const SizedBox(height: Space.xs),
          Text(
            'מסודרים לפי דירה · מנהל הבית מופיע ראשון',
            style: TextStyle(color: context.glass.muted, fontSize: 12),
          ),
          const SizedBox(height: Space.l),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.glass.accent,
                      ),
                    ),
                    for (final member in entry.value)
                      ListTile(
                        key: ValueKey('resident-${member.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: context.glass.chip,
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
