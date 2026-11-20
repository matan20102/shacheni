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

/// Leaves the text fields (a focused field keeps scrolling itself back into
/// view) and taps the editor's save button.
Future<void> tapSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final save = find.byKey(const Key('parking-save'));
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
}

class SlowParking extends LocalParkingRepository {
  SlowParking() : super(apartmentFor: (_) => '12');
  final saved = Completer<void>();
  int writes = 0;
  bool fail = true;
  @override
  Future<String> addSpace(
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
    return super.addSpace(b, label, level, notes);
  }
}

class FailingPublish extends LocalParkingRepository {
  FailingPublish() : super(apartmentFor: (_) => '12');
  bool fail = true;
  @override
  Future<void> publish(String spaceId, DateTime start, DateTime end) async {
    if (fail) throw StateError('פרסום נכשל');
    await super.publish(spaceId, start, end);
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
                : r.url.path.endsWith('ba_parking_add')
                ? '"space-1"'
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
      expect(await repo.addSpace('b', '42', '-1', 'lift'), 'space-1');
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

  testWidgets('one button adds the space and shares it in the same step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = LocalParkingRepository(apartmentFor: (_) => '12');
    await tester.pumpWidget(parkingHarness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parking-share')));
    await tester.pumpAndSettle();
    expect(find.text('שיתוף החניה שלי'), findsWidgets);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('יש להזין את מספר החניה'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('parking-label')), '42');
    await tester.enterText(find.byKey(const Key('parking-level')), '-1');
    await tapSave(tester);
    await tester.pumpAndSettle();
    var snapshot = await repo.load('b');
    final space = snapshot.spaces.single;
    expect(space.label, '42');
    expect(space.level, '-1');
    expect(snapshot.offers.single.ownSpace, isTrue);
    expect(find.text('החניה פורסמה לשכנים'), findsOneWidget);

    // Next time the saved space is already picked: only "when" is needed.
    await tester.tap(find.byKey(const Key('parking-share')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parking-label')), findsNothing);
    final picked = tester.widget<ChoiceChip>(
      find.byKey(ValueKey('parking-pick-${space.id}')),
    );
    expect(picked.selected, isTrue);
    await tester.tap(find.text('בימים קבועים'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    await tester.pumpAndSettle();
    snapshot = await repo.load('b');
    expect(snapshot.spaces, hasLength(1));
    expect(snapshot.offers.length, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a retry after a failed publish does not add the space twice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = FailingPublish();
    await tester.pumpWidget(parkingHarness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parking-share')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parking-label')), '42');
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('פרסום נכשל'), findsWidgets);
    repo.fail = false;
    await tapSave(tester);
    await tester.pumpAndSettle();
    final snapshot = await repo.load('b');
    expect(snapshot.spaces, hasLength(1));
    expect(snapshot.offers, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });

  test('regular schedule: Sunday to Thursday, 7:00–14:00, for a month', () {
    // Wednesday 18.11.2026 at 9:30, in the middle of the first window.
    final now = DateTime(2026, 11, 18, 9, 30);
    final windows = regularParkingWindows(
      days: {7, 1, 2, 3, 4},
      from: const TimeOfDay(hour: 7, minute: 0),
      to: const TimeOfDay(hour: 14, minute: 0),
      weeks: 4,
      now: now,
    );
    expect(windows, hasLength(20));
    expect(
      windows.first.start,
      now,
      reason: 'a window already begun starts now',
    );
    expect(windows.first.end, DateTime(2026, 11, 18, 14));
    for (final w in windows) {
      expect({7, 1, 2, 3, 4}, contains(w.start.weekday));
      expect(w.end.hour, 14);
    }
    expect(parkingDaysLabel({7, 1, 2, 3, 4}), 'א׳–ה׳');
    expect(parkingDaysLabel({...parkingWeekOrder}), 'כל יום');
  });

  test('regular schedule past midnight ends the next morning', () {
    final windows = regularParkingWindows(
      days: {DateTime.friday},
      from: const TimeOfDay(hour: 22, minute: 0),
      to: const TimeOfDay(hour: 6, minute: 0),
      weeks: 1,
      now: DateTime(2026, 11, 15, 12),
    );
    expect(windows.single.start, DateTime(2026, 11, 20, 22));
    expect(windows.single.end, DateTime(2026, 11, 21, 6));
  });

  testWidgets('sharing on fixed days publishes each day and saves the notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = LocalParkingRepository(apartmentFor: (_) => '12');
    await repo.addSpace('b', '42', '', '');
    await tester.pumpWidget(parkingHarness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('החניות שלנו'));
    await tester.pumpAndSettle();
    final space = (await repo.load('b')).spaces.single;
    final button = find.byKey(ValueKey('parking-share-${space.id}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('בימים קבועים'));
    await tester.pumpAndSettle();
    final all = find.byKey(const Key('parking-days-all'));
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pumpAndSettle();
    final week = find.byKey(const ValueKey('parking-weeks-1'));
    await tester.ensureVisible(week);
    await tester.tap(week);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parking-level')), '-2');
    await tester.enterText(
      find.byKey(const Key('parking-notes')),
      'שורה ג׳ ליד המעלית',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('בכל יום'), findsOneWidget);
    await tapSave(tester);
    await tester.pumpAndSettle();
    final snapshot = await repo.load('b');
    final expected = regularParkingWindows(
      days: {...parkingWeekOrder},
      from: const TimeOfDay(hour: 7, minute: 0),
      to: const TimeOfDay(hour: 14, minute: 0),
      weeks: 1,
      now: DateTime.now(),
    );
    expect(snapshot.offers, hasLength(expected.length));
    expect(snapshot.spaces.single.level, '-2');
    expect(snapshot.spaces.single.notes, 'שורה ג׳ ליד המעלית');
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
    await tester.tap(find.byKey(const Key('parking-share')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parking-label')), '42');
    final save = find.byKey(const Key('parking-save'));
    await tapSave(tester);
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
      await tester.tap(find.byKey(const Key('parking-share')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('parking-save')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
