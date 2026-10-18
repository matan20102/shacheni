import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/account_widgets.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

import 'building_experience_test.dart' show harness;

Future<void> openBuilding(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('מידע וניהול הבניין'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'profile validates, prevents duplicate saves and retains edits after failure',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildingTheme(),
          home: Scaffold(
            body: ProfileEditor(
              profile: const ResidentProfile(
                name: 'ניסים כהן',
                email: 'resident@example.test',
              ),
              onSave: (name, phone) async {
                calls++;
                expect(name, 'ניסים לוי');
                expect(phone, '0501234567');
                if (fail) {
                  await pending.future;
                  throw StateError('שמירה נכשלה');
                }
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('profile-name')), 'א');
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'ניסים לוי',
      );
      await tester.enterText(find.byKey(const Key('profile-phone')), '123');
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const Key('profile-phone')),
        '0501234567',
      );
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('profile-save')))
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('שמירה נכשלה'), findsOneWidget);
      expect(find.text('ניסים לוי'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('שמירה נכשלה'), findsNothing);
    },
  );

  testWidgets('top account menu edits profile and personalizes greeting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = LocalBuildingRepository();
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('הפרופיל שלי')).dy, lessThan(250));
    await tester.tap(find.text('הפרופיל שלי'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name')), 'ניסים כהן');
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
    expect(repo.profile.name, 'ניסים כהן');
    expect(find.text('שלום, ניסים 👋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'last admin is blocked, cancelling archive preserves home, confirming switches home',
    (tester) async {
      final repo = LocalBuildingRepository();
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await openBuilding(tester);
      await tester.ensureVisible(find.byKey(const Key('building-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-leave')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-lifecycle-confirm')));
      await tester.pumpAndSettle();
      expect(vm.active!.id, 'garden');
      expect(
        find.textContaining('מנהל הבניין האחרון צריך למנות מחליף'),
        findsOneWidget,
      );
      await tester.tap(find.text('הבנתי'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('building-archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ביטול'));
      await tester.pumpAndSettle();
      expect(repo.homes, hasLength(2));
      await tester.ensureVisible(find.byKey(const Key('building-archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-archive')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('building-lifecycle-confirm')));
      await tester.pumpAndSettle();
      expect(repo.homes.single.id, 'olive');
      expect(vm.active!.id, 'olive');
      expect(find.byKey(const Key('building-archive')), findsNothing);
      expect(vm.busy, isFalse);
    },
  );

  testWidgets('resident can leave and cannot see archive action', (
    tester,
  ) async {
    final repo = LocalBuildingRepository();
    final vm = BuildingViewModel(repo)..enter();
    await vm.select('olive');
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await openBuilding(tester);
    expect(find.byKey(const Key('building-archive')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('building-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-lifecycle-confirm')));
    await tester.pumpAndSettle();
    expect(repo.homes.single.id, 'garden');
    expect(vm.active!.id, 'garden');
  });

  testWidgets('large text keeps account menu usable on a narrow phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm, textScale: 1.5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    expect(find.text('הפרופיל שלי'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
