import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shacheni_app/data/building/platform_repository.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/platform_console.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

import 'building_experience_test.dart' show harness;

class AuthorizedRepository extends LocalBuildingRepository {
  AuthorizedRepository() : super(seed: false);
  @override
  bool get isPlatformAdmin => true;
  @override
  PlatformRepository get platform => FakeConsole();
}

class FakeConsole extends PlatformRepository {
  bool fail = false, failAction = true;
  int actions = 0;
  final searches = <String>[];
  @override
  Future<ConsolePage> load(
    ConsoleSection section,
    String query,
    int offset,
  ) async {
    searches.add(query);
    if (fail) throw StateError('אין הרשאה לניהול המערכת');
    return ConsolePage([
      ConsoleItem(
        'building',
        'הבית בגינה',
        'הגפן 18',
        const {'מצב': 'פעיל'},
        section == ConsoleSection.buildings
            ? const [ConsoleAction.archive]
            : const [],
      ),
    ], hasMore: offset == 0);
  }

  @override
  Future<void> act(ConsoleAction action, String id, String note) async {
    actions++;
    expect(note, 'בדיקה ידנית');
    if (failAction) throw StateError('לא ניתן לשמור כרגע');
  }
}

void main() {
  testWidgets(
    'authorized account without a building can enter platform console from top menu',
    (tester) async {
      final vm = BuildingViewModel(AuthorizedRepository())..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ניהול המערכת'));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformConsole), findsOneWidget);
      expect(find.text('הבית בגינה'), findsOneWidget);
    },
  );
  test('remote console limits page, maps fields and sends scoped action parameters', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('ba_console')) {
          expect(body, {
            'p_kind': 'users',
            'p_query': 'Resident',
            'p_offset': 25,
          });
          return http.Response(
            jsonEncode({
              'items': List.generate(
                26,
                (i) => {
                  'id': '$i',
                  'name': 'Resident $i',
                  'email': 'resident$i@example.test',
                  'homes': 2,
                  'is_admin': false,
                },
              ),
              'has_more': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        expect(body, {
          'p_action': 'approve_building',
          'p_id': 'member',
          'p_note': 'Review',
        });
        return http.Response(
          'null',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = SupabasePlatformRepository(client);
    final page = await repo.load(ConsoleSection.users, ' Resident ', 25);
    expect(page.items, hasLength(25));
    expect(page.hasMore, isTrue);
    expect(page.items.first.subtitle, 'resident0@example.test');
    await repo.act(ConsoleAction.approveBuilding, 'member', ' Review ');
  });
  test('late search cannot replace current section; denied reload removes sensitive rows', () async {
    final old = Completer<ConsolePage>();
    final current = Completer<ConsolePage>();
    final repository = ControlledConsole([old.future, current.future]);
    final vm = ConsoleViewModel(repository);
    addTearDown(vm.dispose);
    final first = vm.load(search: 'old');
    final second = vm.load(
      nextSection: ConsoleSection.buildings,
      search: 'new',
    );
    current.complete(
      const ConsolePage([ConsoleItem('new', 'New', '', {}, [])]),
    );
    await second;
    old.complete(const ConsolePage([ConsoleItem('old', 'Old', '', {}, [])]));
    await first;
    expect(vm.items.single.id, 'new');
    repository.fail = true;
    await vm.load();
    expect(vm.items, isEmpty);
    expect(vm.error, isNotNull);
    expect(vm.loading, isFalse);
  });
  testWidgets(
    'console works on phone, debounces search and preserves reason on failed action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeConsole();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildingTheme(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PlatformConsole(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('console-search')), 'הגפן');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(repo.searches.last, 'הגפן');
      await tester.tap(find.byKey(const ValueKey('console-buildings')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ארכוב בניין'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('console-action-confirm')));
      await tester.pumpAndSettle();
      expect(repo.actions, 0);
      await tester.enterText(
        find.byKey(const Key('console-action-reason')),
        'בדיקה ידנית',
      );
      await tester.tap(find.byKey(const Key('console-action-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('לא ניתן לשמור כרגע'), findsOneWidget);
      expect(find.text('בדיקה ידנית'), findsOneWidget);
      repo.failAction = false;
      await tester.tap(find.byKey(const Key('console-action-confirm')));
      await tester.pumpAndSettle();
      expect(repo.actions, 2);
      expect(find.byKey(const Key('console-action-reason')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class ControlledConsole extends PlatformRepository {
  ControlledConsole(this.responses);
  final List<Future<ConsolePage>> responses;
  bool fail = false;
  int calls = 0;
  @override
  Future<ConsolePage> load(ConsoleSection section, String query, int offset) {
    if (fail) return Future.error(StateError('denied'));
    return responses[calls++];
  }

  @override
  Future<void> act(ConsoleAction action, String id, String note) async {}
}
