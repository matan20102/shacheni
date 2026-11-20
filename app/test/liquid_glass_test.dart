import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/app/appearance.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/account_widgets.dart';
import 'package:shacheni_app/features/building/building_app.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

double _luminance(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final hi = math.max(_luminance(a), _luminance(b));
  final lo = math.min(_luminance(a), _luminance(b));
  return (hi + .05) / (lo + .05);
}

Widget themed(
  Widget home, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(highContrast: highContrast),
    child: child!,
  ),
  home: home,
);

void main() {
  for (final t in [GlassTokens.light, GlassTokens.darkTokens]) {
    test('${t.brightness.name} colors keep text readable (4.5:1)', () {
      // Text sits on glass over the page; check the most see-through glass
      // over every backdrop color, and on the solid sheet.
      final surfaces = [
        for (final under in [t.background, ...t.gradient])
          for (final fill in [t.glass, t.glassMine, t.glassAccent])
            Color.alphaBlend(fill, under),
        t.sheet,
      ];
      for (final surface in surfaces) {
        expect(contrast(t.ink, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.muted, surface), greaterThanOrEqualTo(4.5));
        expect(contrast(t.accent, surface), greaterThanOrEqualTo(4.5));
      }
      expect(contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('glass panel follows dark mode', (tester) async {
    await tester.pumpWidget(
      themed(
        const GlassBackground(
          child: Scaffold(body: GlassPanel(child: Text('שלום'))),
        ),
        brightness: Brightness.dark,
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(GlassPanel),
            matching: find.byType(DecoratedBox),
          )
          .at(1),
    );
    expect(
      (box.decoration as BoxDecoration).color,
      GlassTokens.darkTokens.glass,
    );
    expect(
      tester.widget<Text>(find.text('שלום')).style?.color ??
          DefaultTextStyle.of(tester.element(find.text('שלום'))).style.color,
      GlassTokens.darkTokens.ink,
    );
  });

  testWidgets('increased contrast turns glass solid, without blur', (
    tester,
  ) async {
    await tester.pumpWidget(
      themed(
        const GlassBackground(
          child: Scaffold(body: GlassPanel(child: Text('שלום'))),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.pumpWidget(
      themed(
        const GlassBackground(
          child: Scaffold(body: GlassPanel(child: Text('שלום'))),
        ),
        highContrast: true,
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('floating tab bar shrinks while scrolling down', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(themed(BuildingExperience(viewModel: vm)));
    await tester.pumpAndSettle();
    FloatingNav nav() => tester.widget(find.byType(FloatingNav));
    expect(nav().compact, isFalse);
    expect(find.text('לוח הבניין'), findsWidgets);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(nav().compact, isTrue);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(nav().compact, isFalse);

    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pumpAndSettle();
    expect(vm.tab, 2);
  });

  testWidgets('appearance choice switches the app to dark mode', (
    tester,
  ) async {
    addTearDown(() => appearance.value = ThemeMode.system);
    await tester.pumpWidget(const BuildingPreviewApp());
    await tester.pumpAndSettle();
    BuildContext ctx() => tester.element(find.byType(BuildingExperience));
    expect(ctx().glass.dark, isFalse);

    showAppearancePicker(ctx());
    await tester.pumpAndSettle();
    await tester.tap(find.text('כהה'));
    await tester.pumpAndSettle();
    expect(appearance.value, ThemeMode.dark);
    expect(ctx().glass.dark, isTrue);
  });
}
