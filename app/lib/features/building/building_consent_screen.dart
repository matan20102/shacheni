import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/auth.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';
import '../../app/brand.dart';

/// One deliberate acceptance of all pending versions. Reading a document never
/// marks it accepted; only the user's checkbox and Continue invoke onAccept.
class BuildingConsentScreen extends StatefulWidget {
  const BuildingConsentScreen({
    super.key,
    required this.documents,
    required this.onAccept,
    required this.onSignOut,
  });
  final List<LegalDoc> documents;
  final Future<void> Function(List<String>) onAccept;
  final Future<void> Function() onSignOut;
  @override
  State<BuildingConsentScreen> createState() => _BuildingConsentScreenState();
}

class _BuildingConsentScreenState extends State<BuildingConsentScreen> {
  bool accepted = false, busy = false;
  String? error;
  @override
  void didUpdateWidget(BuildingConsentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.documents
        .map((d) => '${d.type}:${d.version}')
        .join('|');
    final current = widget.documents
        .map((d) => '${d.type}:${d.version}')
        .join('|');
    if (previous != current) accepted = false;
  }

  @override
  Widget build(BuildContext context) => GlassBackground(
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Eyebrow(appNameEnglish),
                      SizedBox(width: 16),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SoftTag(
                            'עוד רגע בבית',
                            icon: Icons.home_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Center(child: BuildingMark(size: 72)),
                  const SizedBox(height: 16),
                  Text(
                    'נעים להכיר,\nנעים להיות שכנים.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'לפני שנכנסים, מכירים את תנאי השימוש\nואת הדרך שבה מטפלים במידע שלך.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: glassMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.documents.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFDCE8EA)),
                          _DocumentLink(
                            document: widget.documents[i],
                            onTap: () => _read(widget.documents[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassPanel(
                    padding: const EdgeInsets.all(8),
                    radius: 22,
                    opacity: .55,
                    child: CheckboxListTile(
                      key: const Key('legal-consent-checkbox'),
                      value: accepted,
                      onChanged: busy
                          ? null
                          : (value) =>
                                setState(() => accepted = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        _acceptanceLabel(),
                        style: const TextStyle(fontSize: 13, height: 1.7),
                      ),
                      activeColor: glassTeal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: glassError),
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    key: const Key('legal-consent-continue'),
                    onPressed: !accepted || busy || widget.documents.isEmpty
                        ? null
                        : _continue,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(busy ? 'רגע, שומרים…' : 'מסכימים וממשיכים'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy ? null : widget.onSignOut,
                    child: const Text(
                      'יציאה מהחשבון',
                      style: TextStyle(color: glassMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  String _acceptanceLabel() {
    final names = widget.documents.map((d) => _documentTitle(d)).toList();
    final labels = names.length < 2
        ? names.join()
        : '${names.take(names.length - 1).join(', ')} ו${names.last}';
    return 'קראתי ואני מאשר את $labels.';
  }

  Future<void> _continue() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onAccept(widget.documents.map((d) => d.type).toList());
    } catch (failure) {
      if (mounted) setState(() => error = buildingErrorMessage(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _read(LegalDoc document) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * .85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _documentTitle(document),
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      Text(
                        'גרסה ${document.version}',
                        style: const TextStyle(fontSize: 11, color: glassMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'סגירת המסמך',
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDCE8EA)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                document.body,
                style: const TextStyle(fontSize: 15, height: 1.85),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('חזרה ל$appNameHebrew'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _documentTitle(LegalDoc document) => switch (document.type) {
  'terms' => 'תנאי השימוש',
  'privacy' => 'מדיניות הפרטיות',
  _ => document.title,
};

class _DocumentLink extends StatelessWidget {
  const _DocumentLink({required this.document, required this.onTap});
  final LegalDoc document;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: glassTeal.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              document.type == 'privacy'
                  ? Icons.shield_outlined
                  : Icons.description_outlined,
              color: glassTeal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _documentTitle(document),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  document.type == 'privacy'
                      ? 'איך מטפלים במידע שלך'
                      : 'הכללים לשימוש ב$appNameHebrew',
                  style: const TextStyle(fontSize: 12, color: glassMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_left_rounded, color: glassMuted, size: 22),
        ],
      ),
    ),
  );
}

@Preview(name: '$appNameHebrew · קבלת פנים ואישור', size: Size(390, 844))
Widget buildingConsentPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildingTheme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: BuildingConsentScreen(
      documents: const [
        LegalDoc(
          type: 'terms',
          version: 'preview',
          title: 'תנאי השימוש',
          body: 'תצוגה מקדימה של המסמך בלבד.',
        ),
        LegalDoc(
          type: 'privacy',
          version: 'preview',
          title: 'מדיניות הפרטיות',
          body: 'תצוגה מקדימה של המסמך בלבד.',
        ),
      ],
      onAccept: consentPreviewAccept,
      onSignOut: consentPreviewSignOut,
    ),
  ),
);
Future<void> consentPreviewAccept(List<String> types) async {}
Future<void> consentPreviewSignOut() async {}
