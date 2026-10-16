import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/auth.dart';
import 'package:shacheni_app/features/building/building_consent_screen.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

const documents = [
  LegalDoc(
    type: 'terms',
    version: '1',
    title: 'Original terms title',
    body: 'Terms body for reading.',
  ),
  LegalDoc(
    type: 'privacy',
    version: '1',
    title: 'Original privacy title',
    body: 'Privacy body for reading.',
  ),
];
Widget consentApp({
  required Future<void> Function(List<String>) onAccept,
  double scale = 1,
  List<LegalDoc> docs = documents,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildingTheme(),
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: BuildingConsentScreen(
    documents: docs,
    onAccept: onAccept,
    onSignOut: () async {},
  ),
);

void main() {
  testWidgets(
    'reading either document does not accept; explicit consent submits both',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      List<String>? acceptedTypes;
      await tester.pumpWidget(
        consentApp(onAccept: (types) async => acceptedTypes = types),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsOneWidget);
      final continueButton = find.byKey(const Key('legal-consent-continue'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.tap(find.text('מדיניות הפרטיות'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy body for reading.'), findsOneWidget);
      await tester.tap(find.byTooltip('סגירת המסמך'));
      await tester.pumpAndSettle();
      expect(acceptedTypes, isNull);
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.ensureVisible(
        find.byKey(const Key('legal-consent-checkbox')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('legal-consent-checkbox')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(acceptedTypes, ['terms', 'privacy']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new document version resets unchecked consent', (tester) async {
    await tester.pumpWidget(consentApp(onAccept: (_) async {}));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('legal-consent-checkbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('legal-consent-checkbox')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.pumpWidget(
      consentApp(
        onAccept: (_) async {},
        docs: [
          documents.first,
          const LegalDoc(
            type: 'privacy',
            version: '2',
            title: 'Privacy',
            body: 'Updated version',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets('consent fits $size with larger text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(consentApp(onAccept: (_) async {}, scale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('מדיניות הפרטיות'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('מדיניות הפרטיות'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
