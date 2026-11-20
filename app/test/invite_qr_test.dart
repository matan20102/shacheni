import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shacheni_app/app/config.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/invite_qr.dart';

import 'building_experience_test.dart' show harness;
import 'resident_directory_test.dart' show directory;

void main() {
  testWidgets('QR carries the invitation link that resolves back to the code', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InviteQrCode(code: 'GARDEN1')),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    final data = tester.widget<InviteQrCode>(find.byType(InviteQrCode)).link;
    expect(data, inviteLink('GARDEN1'));
    expect(joinCodeFromLink(Uri.parse(data)), 'GARDEN1');
  });

  testWidgets('building admin sees the QR panel and opens the lobby notice', (
    tester,
  ) async {
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await directory(tester);
    final home = vm.homes.firstWhere((h) => h.id == 'garden');
    expect(find.byType(InviteQrPanel), findsOneWidget);
    final poster = find.byKey(const Key('invite-qr-poster'));
    await tester.ensureVisible(poster);
    await tester.pumpAndSettle();
    await tester.tap(poster);
    await tester.pumpAndSettle();
    expect(find.byType(InvitePoster), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('invite-poster-code')))
          .data,
      home.code,
    );
    expect(find.text(inviteLink(home.code)), findsOneWidget);
  });

  testWidgets('ordinary resident also gets the invitation QR', (tester) async {
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    await vm.select('olive');
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await directory(tester, buildingId: 'olive');
    expect(vm.active!.isAdmin, isFalse);
    expect(find.byType(InviteQrPanel), findsOneWidget);
  });

  testWidgets('building picker offers the lobby QR to admins', (tester) async {
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('building-invite-qr'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(InvitePoster), findsOneWidget);
    expect(find.textContaining(vm.active!.name), findsWidgets);
  });

  testWidgets('residents can invite but only admins can change the code', (
    tester,
  ) async {
    final vm = BuildingViewModel(LocalBuildingRepository())..enter();
    await vm.select('olive');
    addTearDown(vm.dispose);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('building-selector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('building-invite-qr')), findsOneWidget);
    expect(find.byKey(const Key('building-code-rotate')), findsNothing);
  });
}
