import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/local_parking_repository.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';
import 'package:shacheni_app/features/building/parking_screen.dart';

import 'building_experience_test.dart' show harness;

class CodeCheckingRepository extends LocalBuildingRepository {
  int lookups = 0;
  @override
  BuildingHome? resolveCode(String code) {
    lookups++;
    return null;
  }
}

class BlankAuthorRepository extends LocalBuildingRepository {
  @override
  List<BoardPost> posts(String buildingId) => [
    BoardPost(
      id: 'blank-author',
      buildingId: buildingId,
      author: '',
      apartment: '12',
      text: 'עדכון ללא שם מחבר',
      kind: PostKind.notice,
      createdAt: DateTime.now(),
    ),
  ];
}

void main() {
  testWidgets(
    'blank join code stays local and keyboard search checks a filled code',
    (tester) async {
      final repo = CodeCheckingRepository();
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('הצטרפות עם קוד בניין'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('בדיקת הקוד'));
      await tester.pumpAndSettle();
      expect(repo.lookups, 0);
      expect(find.text('יש להזין את קוד הבניין'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'UNKNOWN');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(repo.lookups, 1);
      expect(find.text('לא נמצא בניין עם הקוד הזה'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a board author with no display name has a safe avatar', (
    tester,
  ) async {
    final vm = BuildingViewModel(BlankAuthorRepository())
      ..enter()
      ..navigate(1);
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('board-post-blank-author')),
        matching: find.text('ש'),
      ),
      findsOneWidget,
    );
    expect(find.text('עדכון ללא שם מחבר'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'moving parking start to the next day preserves the full duration',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = LocalParkingRepository(apartmentFor: (_) => '12');
      await repo.addSpace('b', '42', '', '');
      final space = (await repo.load('b')).spaces.single;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('he'),
          supportedLocales: const [Locale('he')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildingTheme(),
          home: Scaffold(
            body: ParkingScreen(
              repository: repo,
              buildingId: 'b',
              apartment: '12',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parking-section-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('parking-share-${space.id}')));
      await tester.pumpAndSettle();
      final l = MaterialLocalizations.of(
        tester.element(find.byType(ParkingEditor)),
      );
      await tester.tap(find.byKey(const Key('parking-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final tomorrow = DateUtils.dateOnly(DateTime.now())
          .add(const Duration(days: 1));
      await tester.enterText(
        find.byType(TextField),
        l.formatCompactDate(tomorrow),
      );
      await tester.tap(find.text(l.okButtonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.okButtonLabel));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('parking-save')));
      await tester.tap(find.byKey(const Key('parking-save')));
      await tester.pumpAndSettle();
      final offer = (await repo.load('b')).offers.single;
      expect(DateUtils.dateOnly(offer.startsAt), tomorrow);
      expect(offer.endsAt.difference(offer.startsAt), const Duration(hours: 2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
