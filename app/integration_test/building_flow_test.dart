import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/board_read_store.dart';
import 'package:shacheni_app/features/building/building_app.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'device reading positions persist and remain isolated by account',
    (tester) async {
      final building = 'integration-${DateTime.now().microsecondsSinceEpoch}';
      final first = DeviceBoardReadStore('integration-reader-a');
      final position = BoardReadPosition(DateTime.utc(2026, 10, 15), 'post-a');
      try {
        await first.save(building, position);
        final reopened = DeviceBoardReadStore('integration-reader-a');
        expect((await reopened.load(building))!.postId, 'post-a');
        await reopened.save(
          building,
          BoardReadPosition(DateTime.utc(2026, 10, 1), 'older'),
        );
        expect((await first.load(building))!.postId, 'post-a');
        expect(
          await DeviceBoardReadStore('integration-reader-b').load(building),
          isNull,
        );
        expect(await reopened.load('$building-other'), isNull);
      } finally {
        await first.preferences.remove(
          'naybor.board.read.integration-reader-a.$building',
        );
      }
    },
  );
  testWidgets('native RTL flow: create, publish, reply and switch buildings', (
    tester,
  ) async {
    final repository = LocalBuildingRepository(seed: false);
    final vm = BuildingViewModel(repository)..enter();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('he'),
        supportedLocales: const [Locale('he')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildingTheme(),
        home: BuildingExperience(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת בניין חדש'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('building-address')), 'הגפן');
    await tester.enterText(
      find.byKey(const Key('building-house-number')),
      '18',
    );
    await tester.enterText(find.byKey(const Key('building-apartment')), '12');
    await tester.enterText(
      find.byKey(const Key('building-household-name')),
      'משפחת כהן',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('building-create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-create-submit')));
    await tester.pumpAndSettle();
    expect(vm.active!.name, 'הגפן 18');
    expect(vm.active!.householdName, 'משפחת כהן');
    expect(vm.active!.isAdmin && vm.active!.isApartmentAdmin, isTrue);
    final firstBuildingId = vm.active!.id;

    await tester.tap(find.text('לוח הבניין').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('board-new-post')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('board-post-text')),
      'שלום מהאייפון',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('board-post-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('board-post-submit')));
    await tester.pumpAndSettle();
    expect(find.text('שלום מהאייפון'), findsOneWidget);
    final viewport = tester.getRect(
      find.byKey(ValueKey('board-${vm.active!.id}')),
    );
    final card = tester.getRect(
      find.byKey(Key('board-post-${vm.posts.single.id}')),
    );
    expect(card.top, closeTo(viewport.top + 2, 3));
    await tester.tap(find.text('0 תגובות'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'איזה כיף להיות שכנים');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('שליחת תגובה'));
    await tester.pumpAndSettle();
    expect(find.text('איזה כיף להיות שכנים'), findsOneWidget);
    expect(vm.posts.single.replies.single.text, 'איזה כיף להיות שכנים');
    await tester.tap(find.byTooltip('סגירת שיחה'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת בניין חדש'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('building-address')), 'הזית');
    await tester.enterText(find.byKey(const Key('building-house-number')), '7');
    await tester.enterText(find.byKey(const Key('building-apartment')), '4');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('building-create-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-create-submit')));
    await tester.pumpAndSettle();
    expect(vm.active!.name, 'הזית 7');
    expect(vm.posts, isEmpty);
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הגפן 18'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('לוח הבניין').last);
    await tester.pumpAndSettle();
    expect(vm.active!.id, firstBuildingId);
    expect(find.text('שלום מהאייפון'), findsOneWidget);
    expect(vm.posts.single.replies.single.text, 'איזה כיף להיות שכנים');
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הצטרפות עם קוד בניין'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-code')), 'NEIGHBOR');
    await tester.tap(find.text('בדיקת הקוד'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-apartment')), '99');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-household-name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-apartment')), '12');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-household-name')), findsNothing);
    expect(find.text('מצטרפים לבית קיים'), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join-submit')));
    await tester.pumpAndSettle();
    expect(vm.pending.single.apartmentHasAdmin, isTrue);
    expect(vm.pending.single.requestedHouseholdName, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });
}
