import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

import 'building_experience_test.dart' show harness;

// A controlled adapter isolates widget behavior from Supabase SDK auth timers.
class ControlledRepository extends LocalBuildingRepository {
  ControlledRepository() : super(seed: false);
  bool fail = true;
  @override
  bool get isRemote => true;
  @override
  BuildingHome createBuilding(
    String name,
    String address,
    String apartment,
    int entrances, {
    String householdName = '',
    String? entrance,
  }) {
    if (fail) throw StateError('לא ניתן לשמור כרגע. נסה שוב.');
    return super.createBuilding(
      name,
      address,
      apartment,
      entrances,
      householdName: householdName,
      entrance: entrance,
    );
  }
}

class PendingRepository extends ControlledRepository {
  @override
  List<JoinApplication> get applications => const [
    JoinApplication(
      id: 'pending',
      building: BuildingHome(
        id: 'building',
        name: 'בניין חדש',
        address: 'הגפן, רמת גן',
        code: '',
        apartment: '',
      ),
      apartment: '12',
      apartmentHasAdmin: true,
      buildingApproved: true,
      apartmentApproved: false,
    ),
  ];
}

void main() {
  for (final pending in [true, false]) {
    testWidgets('foreground request sync is ${pending ? 5 : 20} seconds', (
      tester,
    ) async {
      final repo = PollingRepository(pending);
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, pending ? 1 : 0);
      if (!pending) {
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(repo.refreshes, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'an approval arriving while updates are open is shown and acknowledged',
    (tester) async {
      final repo = LocalBuildingRepository(seed: false);
      final request = repo.apply(repo.resolveCode('NEIGHBOR')!, '99');
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-updates')));
      await tester.pumpAndSettle();
      expect(find.text('התקבלת לבניין'), findsNothing);
      repo.approve(request.id, byBuildingAdmin: true);
      await vm.synchronize();
      await tester.pumpAndSettle();
      expect(find.text('התקבלת לבניין'), findsOneWidget);
      expect(repo.approvalUpdates, isEmpty);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('building-updates-badge')))
            .isLabelVisible,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('failed save retains the optional-name form and allows retry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = ControlledRepository();
    final vm = BuildingViewModel(repository);
    await vm.initialize();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הבניינים שלי'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת בניין חדש'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('building-address')),
      'הגפן, רמת גן',
    );
    await tester.enterText(find.byKey(const Key('building-house-number')), '4');
    await tester.enterText(find.byKey(const Key('building-apartment')), '12');
    await tester.ensureVisible(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    expect(find.text('לא ניתן לשמור כרגע. נסה שוב.'), findsOneWidget);
    expect(vm.busy, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'הגפן, רמת גן',
    );
    repository.fail = false;
    await tester.ensureVisible(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יוצרים את הבניין'));
    await tester.pumpAndSettle();
    expect(vm.active!.name, 'הגפן 4, רמת גן');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'live applicant sees status without simulation or approval controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = BuildingViewModel(PendingRepository());
      await vm.initialize();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('building-updates-badge')))
            .isLabelVisible,
        isFalse,
      );
      expect(find.text('בקשות ההצטרפות שלי'), findsNothing);
      await tester.tap(find.byTooltip('עדכונים ובקשות'));
      await tester.pumpAndSettle();
      expect(find.text('הדמיית אישור מנהל הבניין'), findsNothing);
      expect(find.text('הדמיית אישור מנהל הדירה'), findsNothing);
      expect(find.text('אישור כמנהל הבניין'), findsNothing);
      expect(find.text('אישור כמנהל הדירה'), findsNothing);
      expect(find.text('ביטול הבקשה'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'acceptance becomes unread only after both approvals and clears when opened',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = LocalBuildingRepository(seed: false);
      final request = repo.apply(repo.resolveCode('NEIGHBOR')!, '12');
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      Badge badge() =>
          tester.widget<Badge>(find.byKey(const Key('building-updates-badge')));
      expect(badge().isLabelVisible, isFalse);
      repo.approve(request.id, byBuildingAdmin: true);
      await vm.synchronize();
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
      repo.approve(request.id, byBuildingAdmin: false);
      await vm.synchronize();
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isTrue);
      await tester.tap(find.byKey(const Key('building-updates')));
      await tester.pumpAndSettle();
      expect(find.text('התקבלת לבניין'), findsOneWidget);
      expect(find.text('לפתוח את הבניין'), findsOneWidget);
      expect(repo.approvalUpdates, isEmpty);
      expect(badge().isLabelVisible, isFalse);
      await tester.tap(find.text('לפתוח את הבניין'));
      await tester.pumpAndSettle();
      await vm.synchronize();
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
      await tester.tap(find.byKey(const Key('building-updates')));
      await tester.pumpAndSettle();
      expect(find.text('התקבלת לבניין'), findsNothing);
      expect(find.text('הכול מעודכן'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class PollingRepository extends LocalBuildingRepository {
  PollingRepository(this.hasRequest) : super(seed: false);
  final bool hasRequest;
  int refreshes = 0;
  @override
  bool get isRemote => true;
  @override
  List<JoinApplication> get applications => hasRequest
      ? const [
          JoinApplication(
            id: 'waiting',
            building: BuildingHome(
              id: 'new',
              name: 'New',
              address: 'New',
              code: '',
              apartment: '',
            ),
            apartment: '1',
            apartmentHasAdmin: false,
          ),
        ]
      : const [];
  @override
  Future<void> refresh({String? buildingId}) async {
    refreshes++;
  }
}
