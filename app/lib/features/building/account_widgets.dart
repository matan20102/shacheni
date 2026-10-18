import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';

@Preview(name: 'נייבור · עריכת פרופיל', size: Size(390, 700))
Widget profileEditorPreview() => MaterialApp(
  theme: buildingTheme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: ProfileEditor(
            profile: const ResidentProfile(
              name: 'ניסים כהן',
              email: 'resident@example.test',
            ),
            onSave: (_, _) async {},
          ),
        ),
      ),
    ),
  ),
);

class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.profile,
    required this.onProfile,
    required this.onBuilding,
    this.onSignOut,
    this.onPlatform,
  });
  final ResidentProfile profile;
  final VoidCallback onProfile;
  final VoidCallback? onBuilding, onSignOut, onPlatform;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    key: const Key('account-menu'),
    tooltip: 'החשבון שלי',
    position: PopupMenuPosition.under,
    color: const Color(0xFFF4FAFC),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    onSelected: (value) {
      switch (value) {
        case 'profile':
          onProfile();
        case 'building':
          onBuilding?.call();
        case 'platform':
          onPlatform?.call();
        case 'sign-out':
          onSignOut?.call();
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        enabled: false,
        child: Text(
          profile.name.isEmpty ? 'החשבון שלי' : profile.name,
          style: const TextStyle(color: glassInk, fontWeight: FontWeight.w700),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'profile',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline),
          title: Text('הפרופיל שלי'),
        ),
      ),
      if (onBuilding != null)
        const PopupMenuItem(
          value: 'building',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.apartment_rounded),
            title: Text('מידע וניהול הבניין'),
          ),
        ),
      if (onPlatform != null)
        const PopupMenuItem(
          value: 'platform',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.admin_panel_settings_outlined),
            title: Text('ניהול המערכת'),
          ),
        ),
      if (onSignOut != null)
        const PopupMenuItem(
          value: 'sign-out',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout_rounded),
            title: Text('יציאה מהחשבון'),
          ),
        ),
    ],
    icon: CircleAvatar(
      radius: 21,
      backgroundColor: const Color(0xFFD3ECEA),
      foregroundColor: glassTeal,
      child: profile.name.isEmpty
          ? const Icon(Icons.person_outline_rounded)
          : Text(
              profile.name.characters.first,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    ),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.profile, required this.onSave});
  final ResidentProfile profile;
  final Future<void> Function(String name, String phone) onSave;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.profile.name);
  late final phone = TextEditingController(text: widget.profile.phone);
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(name.text, phone.text);
    } catch (e) {
      if (mounted) setState(() => error = buildingErrorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'הפרופיל שלי',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'ככה השכנים יכירו אותך.',
            style: TextStyle(color: glassMuted),
          ),
          const SizedBox(height: 24),
          if (widget.profile.email.isNotEmpty) ...[
            GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, color: glassTeal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.profile.email,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const Key('profile-name'),
            controller: name,
            enabled: !saving,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'שם מלא'),
            validator: (v) => (v?.trim().length ?? 0) < 2
                ? 'יש להזין שם באורך שני תווים לפחות'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('profile-phone'),
            controller: phone,
            enabled: !saving,
            maxLength: 24,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'טלפון נייד (לא חובה)',
              hintText: '050-1234567',
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              if ((v ?? '').trim().isEmpty) return null;
              return RegExp(r'^(?:9725[0-9]{8}|05[0-9]{8}|5[0-9]{8})$')
                      .hasMatch(digits)
                  ? null
                  : 'יש להזין מספר נייד ישראלי תקין';
            },
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('profile-save'),
              onPressed: saving ? null : save,
              child: Text(saving ? 'שומר…' : 'שמירת פרופיל'),
            ),
          ),
        ],
      ),
    ),
  );
}
