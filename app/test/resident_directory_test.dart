import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/resident_directory.dart';

import 'building_experience_test.dart' show harness;

Future<void> directory(
  WidgetTester tester, {
  String buildingId = 'garden',
}) async {
  await tester.tap(find.byKey(const Key('building-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('building-info-$buildingId')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'admin can promote a resident then leave without orphaning building',
    (tester) async {
      final repo = LocalBuildingRepository();
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await directory(tester);
      expect(
        tester.getTopLeft(find.text('דירה 2')).dy,
        lessThan(
          tester
              .getTopLeft(
                find.descendant(
                  of: find.byType(ResidentDirectory),
                  matching: find.text('דירה 12'),
                ),
              )
              .dy,
        ),
      );
      final row = find.byKey(const ValueKey('resident-neighbor-2-garden'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resident-change-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resident-confirm-role')));
      await tester.pumpAndSettle();
      expect((await repo.residents('garden')).first.isAdmin, isTrue);
      final leave = find.byKey(const Key('building-leave'));
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      await tester.tap(leave);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-lifecycle-confirm')));
      await tester.pumpAndSettle();
      expect(vm.active!.id, 'olive');
      expect(repo.homes, hasLength(1));
    },
  );
  testWidgets(
    'ordinary resident sees people without role controls or platform menu',
    (tester) async {
      final vm = BuildingViewModel(LocalBuildingRepository())..enter();
      await vm.select('olive');
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      expect(find.text('ניהול המערכת'), findsNothing);
      expect(find.text('מידע וניהול הבניין'), findsNothing);
      await tester.tapAt(const Offset(10, 500));
      await tester.pumpAndSettle();
      await directory(tester, buildingId: 'olive');
      final row = find.byKey(const ValueKey('resident-neighbor-2-olive'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resident-change-role')), findsNothing);
      expect(find.text('מנהל הדירה'), findsWidgets);
    },
  );
}
