import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

import 'building_experience_test.dart' show harness;

void main() {
  Future<BuildingViewModel> start(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    return vm;
  }

  testWidgets('"הבית שלי" starts quiet when nothing is open', (tester) async {
    final vm = await start(tester);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-home')), findsOneWidget);
    expect(find.text('אין תשלומים פתוחים. הכול מסודר.'), findsOneWidget);
    expect(find.text('אין כרגע חניה ששיתפת או הזמנת.'), findsOneWidget);
    expect(find.text('אין חוב לוועד'), findsOneWidget);
  });

  testWidgets('shows my open dues, my parking and my posts', (tester) async {
    final vm = await start(tester);
    final home = vm.active!;
    final repo = vm.repository;
    final today = DateUtils.dateOnly(DateTime.now());
    await repo.committee.addCharge(
      home.id,
      title: 'תיקון דלת הכניסה',
      notes: '',
      amount: 120,
      dueOn: today.add(const Duration(days: 5)),
    );
    final space = await repo.parking.addSpace(home.id, '7', '-1', '');
    final from = DateTime.now().add(const Duration(hours: 2));
    await repo.parking.publish(space, from, from.add(const Duration(hours: 3)));
    await vm.run(
      () => repo.publish(home, 'מישהו יכול להשאיל מקדחה?', PostKind.request),
    );

    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    expect(find.text('תיקון דלת הכניסה'), findsOneWidget);
    expect(find.textContaining('120 ₪'), findsWidgets);
    expect(find.textContaining('שיתפת · עדיין פנויה'), findsOneWidget);
    expect(find.text('מישהו יכול להשאיל מקדחה?'), findsOneWidget);
    expect(find.textContaining('בקשה · פתוחה'), findsOneWidget);

    // A row opens the place where the resident acts on it.
    await tester.tap(find.text('תיקון דלת הכניסה'));
    await tester.pumpAndSettle();
    expect(vm.tab, 3);
  });
}
