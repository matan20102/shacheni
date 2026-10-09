import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/backend.dart';
import '../../data/membership.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// S38 — Me.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final lang = context.lang;
    final me = d.me;
    // Real backend: your own name, apartment and building; admin entries by role.
    final access = ref.watch(myAccessProvider);
    final building = currentBuildingName(ref, context);
    final showAdmin = access == null ? d.isAdmin : access.isBuildingAdmin;
    final showPlatform = access == null ? d.isAdmin : access.isPlatformAdmin;

    Widget row(IconData icon, String label, VoidCallback onTap, {String? trailing, Color? color}) => AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: color ?? AppColors.primary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppText.bodyMedium.copyWith(color: color ?? AppColors.ink))),
              if (trailing != null) StatusChip(trailing, tone: Tone.accent),
              Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint, textDirection: Directionality.of(context)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.meTitle)),
      body: PageBody(
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    PersonAvatar(me, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(access?.fullName ?? (me.firstHe == 'מתן' && lang == 'he' ? 'מתן לוי' : 'Matan Levy'), style: AppText.h2),
                          Text(l.apartmentIn(access?.membership?.apartment ?? me.apartment, building), style: AppText.small),
                          const SizedBox(height: 4),
                          StatusChip(l.verifiedResident(building), tone: Tone.success, icon: Icons.verified_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [RatingText(me), const SizedBox(height: 2), Text(l.reviewsTitle, style: AppText.tiny)]),
                    Column(children: [Text('${me.completed}', style: AppText.h2), Text(l.txCompleted, style: AppText.tiny)]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          row(Icons.edit_outlined, l.editProfile, () => context.push('/me/edit')),
          row(Icons.local_parking_rounded, l.mySpacesTitle, () => context.push('/parking/spaces')),
          row(Icons.receipt_long_rounded, l.historyTitle, () => context.push('/history')),
          row(Icons.settings_outlined, l.settingsTitle, () => context.push('/settings')),
          if (showAdmin || showPlatform) const SizedBox(height: 6),
          if (showAdmin)
            row(Icons.admin_panel_settings_rounded, l.adminArea, () => context.push('/admin'),
                trailing: access == null && d.pendingApplicationCount > 0 ? '${d.pendingApplicationCount}' : null),
          if (showPlatform) row(Icons.domain_add_rounded, l.platformArea, () => context.push('/platform')),
          const SizedBox(height: 6),
          row(Icons.logout_rounded, l.logOut, () => signOutEverywhere(ref),
              color: AppColors.danger),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gateProvider) != Gate.demo) return const _BackendEditProfileScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      appBar: AppBar(title: Text(l.editProfile)),
      body: PageBody(
        children: [
          Center(child: PersonAvatar(d.me, size: 84)),
          const SizedBox(height: 18),
          TextField(controller: TextEditingController(text: context.lang == 'he' ? 'מתן לוי' : 'Matan Levy'), decoration: InputDecoration(labelText: l.fullName)),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: l.apartment),
            child: Text(d.me.apartment, style: AppText.body),
          ),
          const SizedBox(height: 10),
          InfoBanner(l.profileEditNote, icon: Icons.info_outline_rounded, tone: Tone.warn),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => context.pop(), child: Text(l.save)),
        ],
      ),
    );
  }
}

/// S39 against Supabase: your name and phone; the apartment comes from your membership and
/// changes only through the building admin.
class _BackendEditProfileScreen extends ConsumerStatefulWidget {
  const _BackendEditProfileScreen();

  @override
  ConsumerState<_BackendEditProfileScreen> createState() => _BackendEditProfileScreenState();
}

class _BackendEditProfileScreenState extends ConsumerState<_BackendEditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _busy = false;
  bool _tried = false;

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

  bool get _nameOk => _name.text.trim().length >= 2;
  bool get _phoneOk => _phone.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  Future<void> _save() async {
    final l = context.l10n;
    setState(() => _tried = true);
    if (!_nameOk || !_phoneOk) return;
    setState(() => _busy = true);
    try {
      await ref.read(membershipRepoProvider).updateProfile(fullName: _name.text.trim(), phone: _phone.text);
      await ref.read(gateProvider.notifier).refresh(); // reload name/phone everywhere
      if (!mounted) return;
      showSnack(context, l.saved);
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
    final membership = ref.watch(myAccessProvider)?.membership;
    return Scaffold(
      appBar: AppBar(title: Text(l.editProfile)),
      body: PageBody(
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l.fullName, errorText: _tried && !_nameOk ? l.fieldRequired : null),
          ),
          const SizedBox(height: 12),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.phoneLabel,
                hintText: '050-000-0000',
                errorText: _tried && !_phoneOk ? l.phoneInvalid : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: InputDecoration(labelText: l.apartment, enabled: false),
            child: Text(
              membership == null ? '—' : l.apartmentIn(membership.apartment, membership.buildingName),
              style: AppText.body,
            ),
          ),
          const SizedBox(height: 10),
          InfoBanner(l.profileEditNote, icon: Icons.info_outline_rounded, tone: Tone.warn),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.save),
          ),
        ],
      ),
    );
  }
}

/// S41 — settings (language, notifications, legal documents, demo tools).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pickup = true;
  bool _parking = true;

  /// Moving out (real backend): confirm, leave, and the router takes you to the join screen.
  Future<void> _leave(String building) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveBuildingTitle(building)),
        content: Text(l.leaveBuildingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.leaveBuilding),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(membershipRepoProvider).leaveBuilding();
      if (mounted) showSnack(context, l.leftBuilding);
      await ref.read(gateProvider.notifier).refresh();
    } catch (e) {
      if (mounted) showSnack(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider);
    final demoTools = ref.watch(demoToolsProvider);
    final backend = ref.watch(backendStatusProvider).value;
    final membership = ref.watch(myAccessProvider)?.membership;
    final d = ref.watch(demoProvider).data;
    final active = d.myTxns.any((t) => t.status == TxStatus.inProgress || t.status == TxStatus.awaitingSettlement);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: PageBody(
        children: [
          Text(l.languageLabel, style: AppText.h3),
          const SizedBox(height: 10),
          PillTabs(
            labels: [l.hebrew, l.english],
            index: locale.languageCode == 'he' ? 0 : 1,
            onChanged: (i) => ref.read(localeProvider.notifier).set(Locale(i == 0 ? 'he' : 'en')),
          ),
          SectionHeader(l.notifSettings),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(value: _pickup, onChanged: (v) => setState(() => _pickup = v), title: Text(l.notifNewPickup)),
                SwitchListTile(value: _parking, onChanged: (v) => setState(() => _parking = v), title: Text(l.notifNewParking)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(l.alwaysOn, style: AppText.tiny),
                ),
              ],
            ),
          ),
          SectionHeader(l.legalDocs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (type, label) in [
                  ('terms', l.termsOfService),
                  ('privacy', l.privacyPolicy),
                  ('rules', l.communityRules),
                ])
                  ListTile(
                    title: Text(label),
                    trailing: Icon(Icons.chevron_right_rounded, textDirection: Directionality.of(context)),
                    onTap: () => context.push('/doc/$type'),
                  ),
              ],
            ),
          ),
          SectionHeader(l.demoSection),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: demoTools,
                  onChanged: (v) => ref.read(demoToolsProvider.notifier).set(v),
                  title: Text(l.showDemoTools),
                ),
                ListTile(
                  leading: Icon(switch (backend) {
                    BackendStatus.connected => Icons.cloud_done_rounded,
                    BackendStatus.unreachable => Icons.cloud_off_rounded,
                    _ => Icons.cloud_outlined,
                  }),
                  title: Text(l.serverStatus),
                  subtitle: Text(switch (backend) {
                    BackendStatus.connected => l.serverConnected,
                    BackendStatus.unreachable => l.serverUnreachable,
                    BackendStatus.notConfigured => l.serverNotConfigured,
                    null => '…',
                  }),
                  onTap: () => ref.invalidate(backendStatusProvider),
                ),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: Text(l.resetDemo),
                  onTap: () {
                    ref.read(demoProvider.notifier).reset();
                    showSnack(context, l.resetDemo);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (membership?.status == 'approved') ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1.4),
              ),
              onPressed: () => _leave(membership!.buildingName),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.leaveBuilding),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.4),
            ),
            onPressed: () => showSnack(context, active ? l.deleteBlocked : l.deleteAccount),
            child: Text(l.deleteAccount),
          ),
          const SizedBox(height: 14),
          Center(child: Text('${l.appVersion} 0.1.0 (prototype)', style: AppText.tiny)),
        ],
      ),
    );
  }
}
