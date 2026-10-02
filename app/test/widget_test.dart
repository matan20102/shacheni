import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shacheni_app/app/app.dart';
import 'package:shacheni_app/data/demo_data.dart';
import 'package:shacheni_app/data/models.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('he');
    await initializeDateFormatting('en');
  });

  testWidgets('app starts on the Welcome screen in Hebrew (RTL)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    // A Hebrew device resolves to Hebrew (PRD §5.4: saved choice → device → Hebrew).
    tester.platformDispatcher.localeTestValue = const Locale('he');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const ProviderScope(child: ShacheniApp()));
    await tester.pumpAndSettle();

    expect(find.text('שכני'), findsWidgets);
    final dir = Directionality.of(tester.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);
  });

  group('DemoData rules', () {
    test('handoff code locks after 5 wrong attempts and accepts the right code', () {
      final d = DemoData();
      final q = d.request('d4'); // accepted request where I am the helper
      d.markCollected(q.id);
      for (var i = 0; i < 4; i++) {
        expect(d.enterCode(q.id, '0000'), CodeResult.wrong);
      }
      expect(d.enterCode(q.id, '0000'), CodeResult.locked);
      // even the correct code is refused while locked
      expect(d.enterCode(q.id, q.code), CodeResult.locked);
    });

    test('correct code completes the delivery and awaits settlement', () {
      final d = DemoData();
      final q = d.request('d4');
      d.markCollected(q.id);
      expect(d.enterCode(q.id, q.code), CodeResult.ok);
      expect(q.status, RequestStatus.completed);
      expect(d.txn(q.txId!).status, TxStatus.awaitingSettlement);
      d.paymentConfirmReceived(q.txId!);
      expect(d.txn(q.txId!).status, TxStatus.completed);
    });

    test('door delivery is refused without the requester authorization', () {
      final d = DemoData();
      final q = d.request('d4');
      expect(q.doorAllowed, isFalse);
      expect(d.submitDoorDelivery(q.id), isFalse);
      d.allowDoor(q.id);
      expect(d.submitDoorDelivery(q.id), isTrue);
      expect(q.status, RequestStatus.delivered);
      expect(q.handoffMethod, HandoffMethod.doorPhoto);
    });

    test('accepting an offer rejects the others and creates a transaction', () {
      final d = DemoData();
      final q = d.request('d3');
      d.acceptOffer(q.id, 'o1');
      expect(q.offers.firstWhere((o) => o.id == 'o2').status, OfferStatus.rejected);
      expect(q.status, RequestStatus.accepted);
      expect(q.txId, isNotNull);
      expect(q.code.length, 4);
    });

    test('overlapping own listings of the same space are detected', () {
      final d = DemoData();
      final l = d.listing('l4');
      expect(d.overlappingListing(l.spaceLabel, l.start.add(const Duration(hours: 1)), l.end.add(const Duration(hours: 1))), isNotNull);
      expect(d.overlappingListing(l.spaceLabel, l.end, l.end.add(const Duration(hours: 2))), isNull);
    });
  });
}
