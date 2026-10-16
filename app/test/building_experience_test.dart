import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/building_app.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

Widget harness(BuildingViewModel vm, {double textScale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: BuildingExperience(viewModel: vm),
);

void main() {
  testWidgets('publishing and commenting updates the current building board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = BuildingViewModel(LocalBuildingRepository())
      ..enter()
      ..navigate(1);
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('פרסום חדש'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'שלום לשכנים החדשים');
    await tester.tap(find.text('פרסום בלוח'));
    await tester.pumpAndSettle();
    expect(vm.posts.where((p) => p.text == 'שלום לשכנים החדשים'), hasLength(1));
    final card = find.ancestor(
      of: find.text('שלום לשכנים החדשים'),
      matching: find.byType(GlassPanel),
    );
    final commentButton = find.descendant(
      of: card,
      matching: find.text('0 תגובות'),
    );
    await tester.ensureVisible(commentButton);
    await tester.pumpAndSettle();
    await tester.tap(commentButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ברוכים הבאים!');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('שליחת תגובה'));
    await tester.pumpAndSettle();
    expect(find.text('ברוכים הבאים!'), findsOneWidget);
    expect(
      vm.posts
          .firstWhere((p) => p.text == 'שלום לשכנים החדשים')
          .replies
          .single
          .text,
      'ברוכים הבאים!',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new building validates fields and becomes selected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הבית בגינה').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת בניין חדש'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('יוצרים את הבניין'));
    await tester.tap(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    expect(find.text('יש להזין כתובת'), findsOneWidget);
    expect(find.text('יש להזין מספר דירה בספרות בלבד'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('building-address')), 'הדרים');
    await tester.enterText(find.byKey(const Key('building-house-number')), '4');
    await tester.enterText(find.byKey(const Key('building-apartment')), '999');
    await tester.ensureVisible(find.text('יוצרים את הבניין'));
    await tester.tap(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    expect(vm.active!.name, 'הדרים 4');
    expect(vm.active!.apartment, '999');
    expect(vm.posts, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'join screen needs both simulated approvals for an existing apartment',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = BuildingViewModel(LocalBuildingRepository())..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.text('הבית בגינה').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('הצטרפות עם קוד בניין'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'NEIGHBOR');
      await tester.tap(find.text('בדיקת הקוד'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '12');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('שליחת בקשת הצטרפות'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('שליחת בקשת הצטרפות'));
      await tester.pumpAndSettle();
      expect(vm.pending.single.apartmentHasAdmin, isTrue);
      await tester.tap(find.byKey(const Key('building-updates')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('הדמיית אישור מנהל הדירה'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('הדמיית אישור מנהל הדירה'));
      await tester.pumpAndSettle();
      expect(vm.homes, hasLength(2));
      expect(vm.active!.id, 'garden');
      expect(vm.pending.single.apartmentApproved, isTrue);
      await tester.ensureVisible(find.text('הדמיית אישור מנהל הבניין'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('הדמיית אישור מנהל הבניין'));
      await tester.pumpAndSettle();
      expect(vm.homes, hasLength(3));
      expect(vm.active!.id, 'new-neighbor');
      expect(vm.pending, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (const Size(390, 844), 320.0),
    (const Size(844, 390), 226.0),
  ]) {
    testWidgets('conversation remains usable with keyboard at ${scenario.$1}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(scenario.$1);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetViewInsets);
      final repository = LocalBuildingRepository(seed: false);
      final home = repository.createBuilding('', 'הגפן 18', '12', 1);
      repository.publish(home, 'בדיקת מקלדת', PostKind.notice);
      final vm = BuildingViewModel(repository)
        ..enter()
        ..navigate(1);
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('0 תגובות'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0 תגובות'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'תגובה מהטלפון');
      tester.view.viewInsets = FakeViewPadding(
        bottom: scenario.$2 * tester.view.devicePixelRatio,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('שליחת תגובה'));
      await tester.pumpAndSettle();
      expect(vm.posts.single.replies.single.text, 'תגובה מהטלפון');
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1200, 800),
  ]) {
    testWidgets('all tabs render at $size with enlarged Hebrew text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = BuildingViewModel(LocalBuildingRepository())..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm, textScale: 1.3));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        vm.navigate(i);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $i at $size');
      }
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
    });
  }
}
