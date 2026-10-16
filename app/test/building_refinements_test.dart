import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

import 'building_experience_test.dart' show harness;

class CountingRepository extends LocalBuildingRepository {
  int refreshes = 0;
  @override
  bool get isRemote => true;
  @override
  Future<void> refresh({String? buildingId}) async {
    refreshes++;
  }
}

void main() {
  testWidgets('creation has no entrance division and saves the family name', (
    tester,
  ) async {
    final vm = BuildingViewModel(LocalBuildingRepository(seed: false))..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת בניין חדש'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('building-address')),
      'הגפן, רמת גן',
    );
    await tester.enterText(
      find.byKey(const Key('building-house-number')),
      '18',
    );
    await tester.enterText(find.byKey(const Key('building-apartment')), '12');
    await tester.enterText(
      find.byKey(const Key('building-household-name')),
      'משפחת כהן',
    );
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.byKey(const Key('apartment-entrance')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('building-create-submit')));
    await tester.tap(find.byKey(const Key('building-create-submit')));
    await tester.pumpAndSettle();
    expect(vm.active!.entrances, 1);
    expect(vm.active!.entrance, isNull);
    expect(vm.active!.householdName, 'משפחת כהן');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('board opens at the newest compact posts at the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = LocalBuildingRepository(seed: false);
    final home = repo.createBuilding('', 'הגפן 18', '12', 2);
    for (var i = 0; i < 12; i++) {
      repo.publish(home, 'מודעה $i', PostKind.notice);
    }
    final vm = BuildingViewModel(repo)
      ..enter()
      ..navigate(1);
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byKey(ValueKey('board-${home.id}')));
    expect(
      tester.getBottomLeft(find.text('מודעה 11')).dy,
      lessThanOrEqualTo(viewport.bottom),
    );
    expect(
      tester.getTopLeft(find.text('מודעה 11')).dy,
      greaterThan(tester.getTopLeft(find.text('מודעה 10')).dy),
    );
    for (final post in vm.posts.take(3)) {
      final rect = tester.getRect(find.byKey(Key('board-post-${post.id}')));
      expect(rect.height, lessThan(190));
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'home name can be edited and adding another building stays in the selector',
    (tester) async {
      final repo = LocalBuildingRepository(seed: false);
      repo.createBuilding('', 'הגפן 18', '12', 2, householdName: 'משפחת כהן');
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      expect(find.text('משפחת כהן'), findsOneWidget);
      expect(find.text('בניין נוסף'), findsNothing);
      expect(find.text('יצירת בניין חדש'), findsNothing);
      await tester.tap(find.byKey(const Key('household-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('household-name')),
        'משפחת לוי',
      );
      await tester.tap(find.text('שמירת שם הבית'));
      await tester.pumpAndSettle();
      expect(vm.active!.householdName, 'משפחת לוי');
      expect(find.text('משפחת לוי'), findsOneWidget);
      await tester.tap(find.byKey(const Key('building-selector')));
      await tester.pumpAndSettle();
      expect(find.text('יצירת בניין חדש'), findsOneWidget);
      expect(find.text('רענון הבניינים והבקשות'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'live screens update quietly and stop polling while backgrounded',
    (tester) async {
      final repo = CountingRepository();
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      final before = repo.refreshes;
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(repo.refreshes, greaterThan(before));
      expect(vm.busy, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = repo.refreshes;
      await tester.pump(const Duration(seconds: 40));
      expect(repo.refreshes, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repo.refreshes, greaterThan(paused));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
