import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shacheni_app/data/building/local_parking_repository.dart';
import 'package:shacheni_app/data/building/parking_repository.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';
import 'package:shacheni_app/features/building/parking_screen.dart';

import 'building_experience_test.dart' show harness;

Widget parkingHarness(ParkingRepository repo, {double scale = 1}) =>
    MaterialApp(
      locale: const Locale('he'),
      supportedLocales: const [Locale('he')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildingTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ParkingScreen(
            repository: repo,
            buildingId: 'b',
            apartment: '12',
          ),
        ),
      ),
    );

Future<String> share(
  LocalParkingRepository owner, {
  String label = '42',
}) async {
  await owner.addSpace('b', label, '-1', 'ליד המעלית');
  final space = (await owner.load('b')).spaces.last;
  final start = DateTime.now().add(const Duration(hours: 1));
  await owner.publish(space.id, start, start.add(const Duration(hours: 2)));
  return (await owner.load('b')).offers.last.id;
}

class SlowParking extends LocalParkingRepository {
  SlowParking() : super(apartmentFor: (_) => '12');
  final saved = Completer<void>();
  int writes = 0;
  bool fail = true;
  @override
  Future<void> addSpace(
    String b,
    String label,
    String level,
    String notes,
  ) async {
    writes++;
    if (fail) {
      await saved.future;
      throw StateError('שמירה נכשלה');
    }
    await super.addSpace(b, label, level, notes);
  }
}

class DelayedParking extends LocalParkingRepository {
  DelayedParking() : super(apartmentFor: (_) => '12');
  final requests = <Completer<ParkingSnapshot>>[];
  @override
  Future<ParkingSnapshot> load(String b) {
    final c = Completer<ParkingSnapshot>();
    requests.add(c);
    return c.future;
  }
}

void main() {
  test(
    'household ownership, atomic first booking, whole window and cancellations',
    () async {
      final store = ParkingMemoryStore();
      final owner = LocalParkingRepository(
        apartmentFor: (_) => '12',
        userId: 'owner',
        store: store,
      );
      final housemate = LocalParkingRepository(
        apartmentFor: (_) => '12',
        userId: 'housemate',
        store: store,
      );
      final guest = LocalParkingRepository(
        apartmentFor: (_) => '2',
        userId: 'guest',
        store: store,
      );
      final other = LocalParkingRepository(
        apartmentFor: (_) => '3',
        userId: 'other',
        store: store,
      );
      final id = await share(owner);
      final before = (await guest.load('b')).offers.single;
      expect((await housemate.load('b')).spaces.single.label, '42');
      await expectLater(guest.addSpace('b', '42', '', ''), throwsStateError);
      final attempts = await Future.wait(
        [guest, other].map((r) async {
          try {
            await r.book(id);
            return true;
          } catch (_) {
            return false;
          }
        }),
      );
      expect(attempts.where((ok) => ok), hasLength(1));
      await guest.book(id); // retry by winner
      final booked = (await guest.load('b')).offers.single;
      expect(booked.startsAt, before.startsAt);
      expect(booked.endsAt, before.endsAt);
      expect(booked.myBooking, isTrue);
      expect(booked.status, 'booked');
      await guest.cancel(id);
      expect((await other.load('b')).offers.single.canBook, isTrue);
      await other.book(id);
      await housemate.cancel(id);
      expect((await other.load('b')).offers.single.status, 'cancelled');
      await expectLater(other.book(id), throwsStateError);
    },
  );

  test(
    'remote adapter sends UTC intervals and fixed resource identifiers',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://parking.example.test',
        'publishable-test',
        httpClient: MockClient((r) async {
          calls.add(r);
          return http.Response(
            r.url.path.endsWith('ba_parking')
                ? '{"spaces":[],"offers":[]}'
                : 'null',
            200,
            headers: {'content-type': 'application/json'},
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseParkingRepository(client);
      await repo.load('b');
      await repo.addSpace('b', '42', '-1', 'lift');
      final start = DateTime(2026, 10, 19, 10);
      await repo.publish('s', start, start.add(const Duration(hours: 2)));
      await repo.book('o');
      await repo.cancel('o');
      expect(calls.map((r) => r.url.path.split('/').last), [
        'ba_parking',
        'ba_parking_add',
        'ba_parking_publish',
        'ba_parking_book',
        'ba_parking_cancel',
      ]);
      final publish = jsonDecode(calls[2].body) as Map;
      expect(publish, {
        'p_space': 's',
        'p_start': start.toUtc().toIso8601String(),
        'p_end': start.add(const Duration(hours: 2)).toUtc().toIso8601String(),
      });
      expect(jsonDecode(calls[3].body), {'p_offer': 'o'});
    },
  );

  test('stale reload cannot restore data after access is denied', () async {
    final repo = DelayedParking();
    final vm = ParkingViewModel(repo, 'b');
    final first = vm.load(), second = vm.load();
    repo.requests[1].completeError(
      const PostgrestException(message: 'ACCESS_DENIED'),
    );
    await second;
    repo.requests[0].complete(
      const ParkingSnapshot(
        spaces: [ParkingSpace(id: 's', label: '42')],
      ),
    );
    await first;
    expect(vm.snapshot.spaces, isEmpty);
    expect(vm.error, contains('אין הרשאה'));
    vm.dispose();
  });

  testWidgets('phone adds a household space and publishes availability', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = LocalParkingRepository(apartmentFor: (_) => '12');
    await tester.pumpWidget(parkingHarness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parking-add')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('parking-save')));
    await tester.tap(find.byKey(const Key('parking-save')));
    await tester.pumpAndSettle();
    expect(find.text('יש להזין סימון חניה'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('parking-label')), '42');
    await tester.enterText(find.byKey(const Key('parking-level')), '-1');
    await tester.ensureVisible(find.byKey(const Key('parking-save')));
    await tester.tap(find.byKey(const Key('parking-save')));
    await tester.pumpAndSettle();
    final space = (await repo.load('b')).spaces.single;
    final button = find.byKey(ValueKey('parking-share-${space.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('parking-save')));
    await tester.tap(find.byKey(const Key('parking-save')));
    await tester.pumpAndSettle();
    expect((await repo.load('b')).offers.single.ownSpace, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('booking confirmation and cancellation update orders', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = ParkingMemoryStore();
    final owner = LocalParkingRepository(
      apartmentFor: (_) => '12',
      userId: 'owner',
      store: store,
    );
    final guest = LocalParkingRepository(
      apartmentFor: (_) => '2',
      userId: 'guest',
      store: store,
    );
    final id = await share(owner);
    await tester.pumpWidget(parkingHarness(guest));
    await tester.pumpAndSettle();
    final book = find.byKey(ValueKey('parking-book-$id'));
    await tester.ensureVisible(book);
    await tester.tap(book);
    await tester.pumpAndSettle();
    expect((await guest.load('b')).offers.single.status, 'available');
    await tester.tap(find.byKey(const Key('parking-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('מוזמנת עבורך'), findsOneWidget);
    final cancel = find.byKey(ValueKey('parking-cancel-$id'));
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parking-confirm')));
    await tester.pumpAndSettle();
    expect((await guest.load('b')).offers.single.status, 'available');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'lost booking race refreshes list and gives a clear explanation',
    (tester) async {
      final store = ParkingMemoryStore();
      final owner = LocalParkingRepository(
        apartmentFor: (_) => '12',
        userId: 'owner',
        store: store,
      );
      final guest = LocalParkingRepository(
        apartmentFor: (_) => '2',
        userId: 'guest',
        store: store,
      );
      final other = LocalParkingRepository(
        apartmentFor: (_) => '3',
        userId: 'other',
        store: store,
      );
      final id = await share(owner);
      await tester.pumpWidget(parkingHarness(guest));
      await tester.pumpAndSettle();
      final book = find.byKey(ValueKey('parking-book-$id'));
      await tester.ensureVisible(book);
      await tester.tap(book);
      await tester.pumpAndSettle();
      await other.book(id);
      await tester.tap(find.byKey(const Key('parking-confirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining('החניה כבר אינה פנויה'), findsWidgets);
      expect(find.byKey(ValueKey('parking-book-$id')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed save keeps details and blocks duplicate submissions', (
    tester,
  ) async {
    final repo = SlowParking();
    await tester.pumpWidget(parkingHarness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parking-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parking-label')), '42');
    final save = find.byKey(const Key('parking-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(repo.writes, 1);
    repo.saved.complete();
    await tester.pumpAndSettle();
    expect(find.text('שמירה נכשלה'), findsWidgets);
    expect(find.text('42'), findsOneWidget);
    repo.fail = false;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.writes, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'switching buildings never carries parking into the next building',
    (tester) async {
      final repo = LocalBuildingRepository();
      final vm = BuildingViewModel(repo)
        ..enter()
        ..navigate(2);
      addTearDown(vm.dispose);
      await repo.parking.addSpace('garden', '42', '', '');
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parking-section-1')));
      await tester.pumpAndSettle();
      expect(find.text('חניה 42'), findsOneWidget);
      await tester.tap(find.byKey(const Key('building-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('בית הזית'));
      await tester.pumpAndSettle();
      expect(vm.active!.id, 'olive');
      expect(find.text('חניה 42'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'parking and its editor remain usable with large text on narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = LocalParkingRepository(apartmentFor: (_) => '12');
      await tester.pumpWidget(parkingHarness(repo, scale: 1.5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('parking-add')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('parking-save')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
