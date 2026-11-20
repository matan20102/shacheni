import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/building_app.dart';

import 'liquid_glass_test.dart' show themed;
import 'resident_directory_test.dart' show directory;

/// Every screen must pass Flutter's accessibility guidelines: each tappable
/// item has a label for screen readers and tap areas are large enough.
/// Text contrast is checked on the color tokens in liquid_glass_test.dart;
/// Flutter's screenshot-based contrast check misreads text inside scrolling
/// glass panels, so it is not used here.
void main() {
  // Real Hebrew glyphs, so text sizes match the app.
  setUpAll(() async {
    final heebo = FontLoader('Heebo')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Heebo-Variable.ttf').readAsBytesSync(),
          ),
        ),
      );
    await heebo.load();
  });

  Future<BuildingViewModel> open(
    WidgetTester tester, {
    int tab = 0,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    vm.navigate(tab);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      themed(BuildingExperience(viewModel: vm), brightness: brightness),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> check(WidgetTester tester) async {
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
  }

  for (final b in Brightness.values) {
    for (final (tab, name) in [
      (0, 'home'),
      (1, 'board'),
      (2, 'parking'),
      (3, 'committee'),
    ]) {
      testWidgets('$name screen is accessible (${b.name})', (tester) async {
        await open(tester, tab: tab, brightness: b);
        await check(tester);
      });
    }
  }

  testWidgets('building picker is accessible', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    await check(tester);
  });

  testWidgets('post conversation is accessible', (tester) async {
    await open(tester, tab: 1);
    await tester.tap(find.textContaining('תגוב').first);
    await tester.pumpAndSettle();
    await check(tester);
  });

  testWidgets('building info and residents are accessible', (tester) async {
    await open(tester);
    await directory(tester);
    await check(tester);
  });

  testWidgets('new post form is accessible', (tester) async {
    await open(tester, tab: 1);
    await tester.tap(find.byTooltip('פרסום חדש'));
    await tester.pumpAndSettle();
    await check(tester);
  });

  testWidgets('account menu is accessible', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    await check(tester);
  });
}
