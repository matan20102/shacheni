import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/auth.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'backend_join_screens.dart';

/// Placeholder body for every legal document until the owner publishes real text (BR-L5).
/// This is data, not UI copy: it mirrors `legal_document.body_md` for version `0.0-todo`.
const kLegalPlaceholder = 'TODO — legal text to be provided by the owner.';
const kLegalVersion = '0.0-todo';

class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHe = ref.watch(localeProvider).languageCode == 'he';
    return TextButton.icon(
      onPressed: () => ref.read(localeProvider.notifier).set(Locale(isHe ? 'en' : 'he')),
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Text(isHe ? 'English' : 'עברית'),
    );
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageToggle()),
              const Spacer(),
              const HeroIllustration(
                icons: [Icons.directions_car_rounded, Icons.apartment_rounded, Icons.inventory_2_rounded],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(l.appName, style: AppText.h1.copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 14),
              Text(l.welcomeTitle, style: AppText.display.copyWith(fontSize: 27)),
              const SizedBox(height: 18),
              for (final (icon, text) in [
                (Icons.local_parking_rounded, l.welcomeBullet1),
                (Icons.inventory_2_outlined, l.welcomeBullet2),
                (Icons.verified_user_outlined, l.welcomeBullet3),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(icon, color: AppColors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text, style: AppText.body)),
                    ],
                  ),
                ),
              const Spacer(flex: 2),
              if (ref.watch(gateProvider) != Gate.demo)
                const _GoogleSignInButton()
              else ...[
                FilledButton(
                  onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.phone),
                  child: Text(l.getStarted),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.approved),
                    child: Text(l.skipToDemo),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the real backend works out where a signed-in user belongs.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _GoogleSignInButton extends ConsumerStatefulWidget {
  const _GoogleSignInButton();

  @override
  ConsumerState<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<_GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepoProvider).signInWithGoogle();
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.signInFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _signIn,
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w800)),
            ),
      label: Text(context.l10n.continueWithGoogle),
    );
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _ctrl = TextEditingController();
  bool _touched = false;

  bool get _valid => _ctrl.text.replaceAll(RegExp(r'\D'), '').length >= 9;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.welcome)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.phoneTitle, style: AppText.h1),
              const SizedBox(height: 8),
              Text(l.phoneSubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: 28),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.phone,
                  style: AppText.h2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        widthFactor: 1,
                        child: Text('🇮🇱  +972', style: AppText.bodyBold),
                      ),
                    ),
                    hintText: '050-000-0000',
                    errorText: _touched && !_valid ? l.phoneInvalid : null,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  setState(() => _touched = true);
                  if (!_valid) return;
                  ref.read(demoProvider.notifier).act((d) {
                    d.phone = _ctrl.text;
                    d.stage = AuthStage.otp;
                  });
                },
                child: Text(l.sendCode),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final phone = ref.watch(demoProvider).data.phone;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.phone)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.otpTitle, style: AppText.h1),
              const SizedBox(height: 8),
              Text(l.otpSubtitle('+972 $phone'), style: AppText.body.copyWith(color: AppColors.inkSoft)),
              TextButton(
                onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.phone),
                child: Text(l.otpChange),
              ),
              const SizedBox(height: 16),
              Center(
                child: CodeInput(
                  value: _code,
                  length: 6,
                  compact: true,
                  onChanged: (v) => setState(() => _code = v),
                ),
              ),
              const SizedBox(height: 14),
              Center(child: Text(l.otpResendIn('24'), style: AppText.small)),
              const SizedBox(height: 6),
              Center(child: Text(l.otpDemoHint, style: AppText.tiny.copyWith(color: AppColors.accent))),
              const Spacer(),
              FilledButton(
                onPressed: _code.length == 6
                    ? () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.legal)
                    : null,
                child: Text(l.verify),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String legalTitle(BuildContext c, String type) {
  final l = c.l10n;
  return switch (type) {
    'terms' => l.termsOfService,
    'privacy' => l.privacyPolicy,
    'rules' => l.communityRules,
    'declaration' => l.residentDeclaration,
    _ => l.buildingAgreement,
  };
}

/// S04 — consent gate for the current Terms of Service and Privacy Policy (BR-L1).
class LegalConsentScreen extends ConsumerStatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  ConsumerState<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends ConsumerState<LegalConsentScreen> {
  bool _terms = false;
  bool _privacy = false;

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return const _BackendConsentScreen();
    final l = context.l10n;
    Widget row(String type, bool value, ValueChanged<bool> onChanged) =>
        LegalAcceptCard(type: type, version: kLegalVersion, value: value, onChanged: onChanged);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.legalTitle, style: AppText.h1),
              const SizedBox(height: 6),
              Text(l.legalSubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: 18),
              row('terms', _terms, (v) => setState(() => _terms = v)),
              row('privacy', _privacy, (v) => setState(() => _privacy = v)),
              InfoBanner(l.legalPlaceholderNote, icon: Icons.construction_rounded, tone: Tone.warn),
              const Spacer(),
              FilledButton(
                onPressed: _terms && _privacy
                    ? () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.join)
                    : null,
                child: Text(l.legalAcceptContinue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One document on the consent screen: title, version, "read", "I accept".
class LegalAcceptCard extends StatelessWidget {
  const LegalAcceptCard({
    super.key,
    required this.type,
    required this.version,
    required this.value,
    required this.onChanged,
  });

  final String type;
  final String version;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(legalTitle(context, type), style: AppText.h3)),
              Text(l.legalVersion(version), style: AppText.tiny),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            onPressed: () => context.push('/doc/$type'),
            child: Text(l.legalRead),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            title: Text(l.legalAccept, style: AppText.body),
          ),
        ],
      ),
    );
  }
}

/// S04 against Supabase: lists the current documents the user has not accepted yet
/// (a new version re-opens only that document) and records the acceptance server-side.
class _BackendConsentScreen extends ConsumerStatefulWidget {
  const _BackendConsentScreen();

  @override
  ConsumerState<_BackendConsentScreen> createState() => _BackendConsentScreenState();
}

class _BackendConsentScreenState extends ConsumerState<_BackendConsentScreen> {
  Future<List<LegalDoc>>? _docs;
  String? _loadedLocale;
  final _checked = <String>{};
  bool _busy = false;

  void _load(String locale) {
    _loadedLocale = locale;
    _docs = ref.read(authRepoProvider).pendingLegal(locale);
  }

  Future<void> _accept(List<LegalDoc> docs) async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepoProvider).acceptLegal([for (final d in docs) d.type], _loadedLocale!);
      await ref.read(gateProvider.notifier).refresh();
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.loadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider).languageCode;
    if (locale != _loadedLocale) _load(locale);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: FutureBuilder<List<LegalDoc>>(
            future: _docs,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InfoBanner(l.loadFailed, icon: Icons.cloud_off_rounded, tone: Tone.warn),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => setState(() => _load(locale)), child: Text(l.retry)),
                  ],
                );
              }
              final docs = snap.data!;
              final allChecked = docs.every((d) => _checked.contains(d.type));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(onPressed: () => signOutEverywhere(ref), child: Text(l.logOut)),
                  ),
                  Text(l.legalTitle, style: AppText.h1),
                  const SizedBox(height: 6),
                  Text(l.legalSubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
                  const SizedBox(height: 18),
                  for (final d in docs)
                    LegalAcceptCard(
                      type: d.type,
                      version: d.version,
                      value: _checked.contains(d.type),
                      onChanged: (v) => setState(() => v ? _checked.add(d.type) : _checked.remove(d.type)),
                    ),
                  if (docs.any((d) => d.version == kLegalVersion))
                    InfoBanner(l.legalPlaceholderNote, icon: Icons.construction_rounded, tone: Tone.warn),
                  const Spacer(),
                  FilledButton(
                    onPressed: allChecked && !_busy
                        ? () => docs.isEmpty ? ref.read(gateProvider.notifier).refresh() : _accept(docs)
                        : null,
                    child: Text(l.legalAcceptContinue),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// S10 — legal document viewer. Body comes from the legal_document store (placeholder for now).
class LegalDocScreen extends ConsumerWidget {
  const LegalDocScreen({super.key, required this.type});
  final String type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locale = ref.watch(localeProvider).languageCode;
    Widget page(String version, String body) {
      final placeholder = version == kLegalVersion;
      return PageBody(
        children: [
          StatusChip(l.legalVersion(version),
              tone: placeholder ? Tone.warn : Tone.neutral,
              icon: placeholder ? Icons.construction_rounded : Icons.description_outlined),
          const SizedBox(height: 16),
          AppCard(
            child: Directionality(
              textDirection: placeholder ? TextDirection.ltr : Directionality.of(context),
              child: SelectableText(body, style: AppText.body),
            ),
          ),
          if (placeholder) ...[
            const SizedBox(height: 14),
            InfoBanner(l.legalPlaceholderNote, icon: Icons.construction_rounded, tone: Tone.warn),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(legalTitle(context, type))),
      body: ref.watch(gateProvider) == Gate.demo
          ? page(kLegalVersion, kLegalPlaceholder)
          : FutureBuilder<LegalDoc?>(
              future: ref.read(authRepoProvider).currentDoc(type, locale),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doc = snap.data;
                if (doc == null) {
                  return PageBody(children: [InfoBanner(l.loadFailed, icon: Icons.cloud_off_rounded, tone: Tone.warn)]);
                }
                return page(doc.version, doc.body);
              },
            ),
    );
  }
}

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _ctrl = TextEditingController();
  bool _found = false;
  bool _invalid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendJoinScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.joinTitle, style: AppText.h1),
              const SizedBox(height: 8),
              Text(l.joinSubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: 24),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  style: AppText.h2.copyWith(letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: l.joinCodeLabel,
                    errorText: _invalid ? l.joinInvalid : null,
                  ),
                  onChanged: (_) => setState(() {
                    _invalid = false;
                    _found = false;
                  }),
                ),
              ),
              const SizedBox(height: 8),
              Text(l.joinDemoHint(DemoData.joinCode), style: AppText.tiny.copyWith(color: AppColors.accent)),
              const SizedBox(height: 16),
              if (!_found)
                OutlinedButton(
                  onPressed: () {
                    final ok = _ctrl.text.trim().toUpperCase() == d.joinCodeValue;
                    setState(() {
                      _found = ok;
                      _invalid = !ok;
                    });
                  },
                  child: Text(l.joinFind),
                ),
              if (_found) ...[
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
                            Text(d.buildingName.of(context.lang), style: AppText.h2),
                            Text(d.buildingAddress.of(context.lang), style: AppText.small),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (_found)
                FilledButton(
                  onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.apply),
                  child: Text(l.joinConfirm),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApplyScreen extends ConsumerStatefulWidget {
  const ApplyScreen({super.key});

  @override
  ConsumerState<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends ConsumerState<ApplyScreen> {
  final _name = TextEditingController(text: '');
  String? _apartment;
  final _spaces = <String>{};
  bool _noParking = false;
  final _decl = List<bool>.filled(5, false);
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasParking => _spaces.isNotEmpty;

  bool get _declOk => _decl[0] && _decl[1] && _decl[2] && _decl[4] && (!_hasParking || _decl[3]);

  Future<void> _pickApartment() async {
    final d = ref.read(demoProvider).data;
    final picked = await showAppSheet<String>(
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
              for (final a in d.apartments)
                ChoiceChip(
                  label: Text(a),
                  selected: _apartment == a,
                  onSelected: (_) => Navigator.pop(ctx, a),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _apartment = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendApplyScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final decls = [l.decl1, l.decl2, l.decl3, l.decl4, l.decl5];
    final canSubmit = _name.text.trim().isNotEmpty && _apartment != null && _declOk;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.join)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text(l.applyTitle, style: AppText.h1),
            const SizedBox(height: 6),
            Text(l.applySubtitle, style: AppText.body.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo_outlined, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(l.optionalPhoto, style: AppText.small)),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.fullName,
                errorText: _submitted && _name.text.trim().isEmpty ? l.fieldRequired : null,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickApartment,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l.apartment,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
                  errorText: _submitted && _apartment == null ? l.fieldRequired : null,
                ),
                child: Text(_apartment ?? l.apartmentPick,
                    style: AppText.body.copyWith(color: _apartment == null ? AppColors.inkFaint : AppColors.ink)),
              ),
            ),
            SectionHeader(l.parkingSpaces),
            Text(l.parkingOptionalHint, style: AppText.small),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in d.spaceLabels)
                  FilterChip(
                    label: Text(s),
                    selected: _spaces.contains(s),
                    onSelected: (v) => setState(() {
                      v ? _spaces.add(s) : _spaces.remove(s);
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
                if (_noParking) _spaces.clear();
              }),
              title: Text(l.noParking, style: AppText.body),
            ),
            SectionHeader(l.declarationsTitle),
            for (var i = 0; i < 5; i++)
              if (i != 3 || _hasParking)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _decl[i],
                  onChanged: (v) => setState(() => _decl[i] = v ?? false),
                  title: Text(decls[i], style: AppText.body),
                  secondary: i == 4
                      ? TextButton(onPressed: () => context.push('/doc/rules'), child: Text(l.legalRead))
                      : null,
                ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                setState(() => _submitted = true);
                if (!canSubmit) return;
                ref.read(demoProvider.notifier).act((d) => d.submitApplication(
                      name: _name.text.trim(),
                      apartment: _apartment!,
                      spaces: _spaces.toList()..sort(),
                    ));
              },
              child: Text(l.submitRequest),
            ),
          ],
        ),
      ),
    );
  }
}

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(gateProvider) != Gate.demo) return const BackendPendingScreen();
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final mine = d.applications.where((a) => a.isMine).toList();
    final app = mine.isEmpty ? null : mine.first;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageToggle()),
              const SizedBox(height: 8),
              const HeroIllustration(icons: [Icons.hourglass_top_rounded, Icons.verified_user_rounded]),
              const SizedBox(height: 24),
              Text(l.pendingTitle(d.buildingName.of(context.lang)), style: AppText.h1),
              const SizedBox(height: 8),
              Text(l.pendingBody, style: AppText.body.copyWith(color: AppColors.inkSoft)),
              if (app != null) ...[
                SectionHeader(l.pendingSummary),
                AppCard(
                  child: Column(
                    children: [
                      KeyValueRow(l.nameLabel, app.name.of(context.lang)),
                      KeyValueRow(l.apartment, app.apartment),
                      if (app.spaces.isNotEmpty) KeyValueRow(l.parkingSpaces, app.spaces.join(', ')),
                    ],
                  ),
                ),
              ],
              DemoButton(l.pendingDemoApprove, onPressed: () {
                if (app != null) {
                  ref.read(demoProvider.notifier).act((d) => d.decideApplication(app.id, ApplicationStatus.approved));
                } else {
                  ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.approved);
                }
              }),
              const Spacer(),
              OutlinedButton(
                onPressed: () => ref.read(demoProvider.notifier).act((d) => d.stage = AuthStage.join),
                child: Text(l.withdrawRequest),
              ),
              Center(
                child: TextButton(
                  onPressed: () => signOutEverywhere(ref),
                  child: Text(l.logOut),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


