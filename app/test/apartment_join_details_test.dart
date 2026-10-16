import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

import 'building_experience_test.dart' show harness;

class DelayedApartmentRepository extends LocalBuildingRepository {
  final lookups = <String, Completer<ApartmentStatus>>{};
  @override
  Future<ApartmentStatus> apartmentStatus(
    BuildingHome home,
    String apartment, {
    String? entrance,
  }) => (lookups[apartment] = Completer<ApartmentStatus>()).future;
}

Future<void> openJoin(WidgetTester tester, BuildingViewModel vm) async {
  await tester.pumpWidget(harness(vm));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('building-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('הצטרפות עם קוד בניין'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('join-code')), 'NEIGHBOR');
  await tester.tap(find.text('בדיקת הקוד'));
  await tester.pumpAndSettle();
}

Future<void> chooseApartment(WidgetTester tester, String number) async {
  await tester.ensureVisible(find.byKey(const Key('join-apartment')));
  await tester.enterText(find.byKey(const Key('join-apartment')), number);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'existing apartment hides family field and explains both approvals',
    (tester) async {
      final repo = LocalBuildingRepository(seed: false);
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await openJoin(tester, vm);
      await chooseApartment(tester, '99');
      expect(find.byKey(const Key('join-household-name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('join-household-name')),
        'משפחת כהן',
      );
      await chooseApartment(tester, '12א');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('join-apartment')))
            .controller!
            .text,
        '12',
      );
      expect(find.byKey(const Key('join-household-name')), findsNothing);
      expect(find.text('מצטרפים לבית קיים'), findsOneWidget);
      expect(find.textContaining('נדרשים שני האישורים'), findsOneWidget);
      expect(find.byKey(const Key('apartment-entrance')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('join-submit')));
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();
      expect(repo.applications.single.apartment, '12');
      expect(repo.applications.single.entrance, isNull);
      expect(repo.applications.single.requestedHouseholdName, isEmpty);
      expect(repo.homes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'new apartment stages a name and becomes a household only after approval',
    (tester) async {
      final repo = LocalBuildingRepository(seed: false);
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await openJoin(tester, vm);
      await chooseApartment(tester, '00099');
      await tester.ensureVisible(find.byKey(const Key('join-household-name')));
      await tester.enterText(
        find.byKey(const Key('join-household-name')),
        'משפחת כהן',
      );
      await tester.ensureVisible(find.byKey(const Key('join-submit')));
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();
      final request = repo.applications.single;
      expect(request.apartment, '99');
      expect(request.requestedHouseholdName, 'משפחת כהן');
      expect(repo.homes, isEmpty);
      repo.approve(request.id, byBuildingAdmin: true);
      expect(repo.homes.single.householdName, 'משפחת כהן');
      expect(repo.homes.single.isApartmentAdmin, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('late lookup cannot turn an existing home into a new home', (
    tester,
  ) async {
    final repo = DelayedApartmentRepository();
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    await openJoin(tester, vm);
    await chooseApartment(tester, '99');
    await chooseApartment(tester, '12');
    repo.lookups['12']!.complete(
      const ApartmentStatus(exists: true, hasAdmin: true),
    );
    await tester.pumpAndSettle();
    repo.lookups['99']!.complete(
      const ApartmentStatus(exists: false, hasAdmin: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('מצטרפים לבית קיים'), findsOneWidget);
    expect(find.byKey(const Key('join-household-name')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
