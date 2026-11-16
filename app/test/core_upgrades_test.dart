import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shacheni_app/app/config.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/local_parking_repository.dart';
import 'package:shacheni_app/data/building/parking_repository.dart';
import 'package:shacheni_app/data/building/supabase_building_repository.dart';
import 'package:shacheni_app/features/building/account_widgets.dart';
import 'package:shacheni_app/features/building/board_search.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_experience_test.dart' show harness;

Widget page(Widget child) => MaterialApp(
  locale: const Locale('he'),
  supportedLocales: const [Locale('he')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildingTheme(),
  home: Scaffold(body: SafeArea(child: child)),
);

/// A manager's view of somebody else's pending request.
class InboxRepository extends LocalBuildingRepository {
  final rejected = <String>[];
  bool open = true;
  @override
  List<JoinApplication> get applications => [
    if (open)
      JoinApplication(
        id: 'request',
        building: homes.first,
        apartment: '7',
        apartmentHasAdmin: false,
        mine: false,
        applicantName: 'רון לוי',
        canApproveBuilding: true,
      ),
  ];
  @override
  void reject(String id) {
    rejected.add(id);
    open = false;
  }
}

void main() {
  group('invitation links', () {
    test('a link carries the code and reads back in upper case', () {
      expect(
        joinCodeFromLink(Uri.parse(inviteLink('ab12cd34'))),
        'AB12CD34',
      );
    });
    test('other addresses carry no code', () {
      expect(joinCodeFromLink(Uri.parse('https://example.test/')), isNull);
      expect(
        joinCodeFromLink(Uri.parse('https://example.test/?join=a b')),
        isNull,
      );
      expect(
        joinCodeFromLink(Uri.parse('https://example.test/?code=ABCD1234')),
        isNull,
      );
    });
  });

  group('membership', () {
    test('a declined request leaves the list', () {
      final repo = LocalBuildingRepository();
      final request = repo.apply(repo.resolveCode('NEIGHBOR')!, '5');
      repo.reject(request.id);
      expect(repo.applications, isEmpty);
      expect(() => repo.reject(request.id), throwsStateError);
    });

    test('a manager removes a resident but not a manager or themself', () async {
      final repo = LocalBuildingRepository();
      await repo.residents('garden');
      expect(() => repo.removeMember('self-garden'), throwsStateError);
      repo.setAdmin('neighbor-2-garden', true);
      expect(() => repo.removeMember('neighbor-2-garden'), throwsStateError);
      repo.removeMember('neighbor-20-garden');
      expect(
        (await repo.residents('garden')).map((m) => m.id),
        isNot(contains('neighbor-20-garden')),
      );
    });

    test('a resident cannot remove a neighbour', () async {
      final repo = LocalBuildingRepository();
      await repo.residents('garden');
      repo.setAdmin('neighbor-2-garden', true);
      repo.setAdmin('self-garden', false);
      expect(() => repo.removeMember('neighbor-20-garden'), throwsStateError);
    });

    test('rotating the code replaces it for the manager', () {
      final repo = LocalBuildingRepository();
      final before = repo.homes.first.code;
      final next = repo.rotateCode(repo.homes.first);
      expect(next, isNot(before));
      expect(repo.homes.first.code, next);
      expect(repo.resolveCode(before), isNull);
      expect(() => repo.rotateCode(repo.homes.last), throwsStateError);
    });

    test('deleting the account clears the device state', () {
      final repo = LocalBuildingRepository()..updateProfile('דנה כהן', '');
      repo.deleteAccount();
      expect(repo.homes, isEmpty);
      expect(repo.profile.name, isEmpty);
    });
  });

  group('board', () {
    test('own replies can be edited and deleted', () {
      final repo = LocalBuildingRepository();
      repo.reply('help', 'בדרך אליך');
      final reply = repo.posts('garden').firstWhere((p) => p.id == 'help').replies.last;
      expect(reply.id, isNotEmpty);
      repo.editReply(reply.id, ' מגיע בעוד חמש דקות ');
      final edited = repo.posts('garden').firstWhere((p) => p.id == 'help').replies.last;
      expect(edited.text, 'מגיע בעוד חמש דקות');
      expect(edited.edited, isTrue);
      expect(() => repo.editReply(reply.id, '  '), throwsArgumentError);
      repo.removeReply(reply.id);
      expect(
        repo.posts('garden').firstWhere((p) => p.id == 'help').replies,
        hasLength(1),
      );
      expect(() => repo.removeReply(reply.id), throwsStateError);
    });

    test('a report hides the post and reaches the manager', () async {
      final repo = LocalBuildingRepository();
      expect(() => repo.report('mine'), throwsStateError);
      repo.report('help', reason: ' לא קשור לבניין ');
      repo.report('help');
      expect(repo.posts('garden').map((p) => p.id), isNot(contains('help')));
      final reports = await repo.reports('garden');
      expect(reports, hasLength(1));
      expect(reports.single.reasons, ['לא קשור לבניין']);
      expect(repo.reports('olive'), throwsStateError);
    });

    test('a manager keeps or removes reported content', () async {
      final repo = LocalBuildingRepository();
      repo.report('help');
      repo.resolveReport((await repo.reports('garden')).single, remove: false);
      expect(await repo.reports('garden'), isEmpty);
      repo.report('resolved');
      repo.resolveReport((await repo.reports('garden')).single, remove: true);
      expect(await repo.reports('garden'), isEmpty);
      final all = await repo.boardPage('garden');
      expect(all.posts.map((p) => p.id), isNot(contains('resolved')));
    });

    test('search matches posts and replies, newest first', () async {
      final repo = LocalBuildingRepository();
      expect((await repo.boardPage('garden', query: 'מקדחה')).posts.single.id, 'help');
      expect((await repo.boardPage('garden', query: 'דירה 8')).posts.single.id, 'help');
      expect((await repo.boardPage('garden', query: 'אין כזה')).posts, isEmpty);
      final all = await repo.boardPage('garden');
      expect(all.hasMore, isFalse);
      expect(all.posts.first.id, 'mine');
      final older = await repo.boardPage(
        'garden',
        before: all.posts.first.createdAt,
      );
      expect(older.posts.map((p) => p.id), isNot(contains('mine')));
    });

    test('a long board is read a page at a time', () async {
      final repo = LocalBuildingRepository();
      for (var i = 0; i < 40; i++) {
        repo.publish(repo.homes.first, 'פרסום $i', PostKind.notice);
      }
      final first = await repo.boardPage('garden');
      expect(first.posts, hasLength(30));
      expect(first.hasMore, isTrue);
      final second = await repo.boardPage(
        'garden',
        before: first.posts.last.createdAt,
      );
      expect(second.hasMore, isFalse);
      expect(second.posts, isNotEmpty);
      final shown = first.posts.map((p) => p.id).toSet();
      expect(second.posts.where((p) => shown.contains(p.id)), isEmpty);
    });
  });

  group('server adapter', () {
    Map<String, dynamic> state() => {
      'profile': {'full_name': 'דנה', 'email': '', 'phone': ''},
      'homes': [
        {
          'id': 'b',
          'name': 'הבית',
          'address': 'הגפן 1',
          'apartment': '3',
          'code': 'ABCD2345',
          'open_reports': 2,
          'is_admin': true,
          'is_committee': false,
          'is_apartment_admin': true,
        },
      ],
      'applications': [],
      'approval_updates': [],
      'notifications': [
        {
          'id': 'n1',
          'type': 'parking.booked',
          'building_id': 'b',
          'building_name': 'הבית',
          'text': 'P9',
          'starts_at': '2026-11-20T08:00:00Z',
        },
        {
          'id': 'n2',
          'type': 'community.member_removed',
          'building_id': 'gone',
          'building_name': 'בית אחר',
          'text': null,
          'starts_at': null,
        },
      ],
    };
    Map<String, dynamic> post() => {
      'id': 'p',
      'building_id': 'b',
      'author': 'שכן',
      'apartment': '2',
      'text': 'שלום',
      'kind': 'notice',
      'created_at': '2026-11-10T10:00:00Z',
      'mine': false,
      'pinned': false,
      'closed': false,
      'edited': true,
      'replies': [
        {'id': 'r1', 'author': 'דנה', 'text': 'היי', 'mine': true, 'edited': true},
        {'author': 'ישן', 'text': 'בלי מזהה', 'mine': false},
      ],
      'reactions': {},
      'my_reactions': [],
    };

    test('reads updates, report counts and reply identity', () async {
      final calls = <String, Object?>{};
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          final name = request.url.pathSegments.last;
          calls[name] = request.body.isEmpty ? null : jsonDecode(request.body);
          final Object? body = switch (name) {
            'ba_state' => state(),
            'ba_board' => [post()],
            'ba_board_page' => {
              'posts': [post()],
              'has_more': true,
            },
            'ba_reports' => [
              {
                'post_id': 'p',
                'reply_id': 'r1',
                'count': 2,
                'reasons': ['גס'],
                'text': 'היי',
                'post_text': 'שלום',
                'author': 'דנה',
                'apartment': '2',
              },
            ],
            'ba_rotate_code' => 'NEWCODE2',
            _ => null,
          };
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseBuildingRepository(client);
      final vm = BuildingViewModel(repo);
      addTearDown(vm.dispose);
      await vm.initialize();

      expect(vm.updates.map((u) => u.type), [
        'parking.booked',
        'community.member_removed',
      ]);
      expect(vm.updates.first.startsAt, isNotNull);
      expect(vm.updates.last.text, isEmpty);
      expect(vm.notificationCount, 2);
      expect(vm.active!.openReports, 2);
      expect(vm.posts.single.edited, isTrue);
      expect(vm.posts.single.replies.first.id, 'r1');
      expect(vm.posts.single.replies.first.edited, isTrue);
      expect(vm.posts.single.replies.last.id, isEmpty);

      final found = await repo.boardPage(
        'b',
        before: DateTime.utc(2026, 11, 12),
        query: ' שלום ',
      );
      expect(found.hasMore, isTrue);
      expect(calls['ba_board_page'], {
        'p_building': 'b',
        'p_before': '2026-11-12T00:00:00.000Z',
        'p_query': 'שלום',
      });

      final reports = await repo.reports('b');
      expect(reports.single.replyId, 'r1');
      expect(reports.single.count, 2);
      await repo.resolveReport(reports.single, remove: true);
      expect(calls['ba_report_resolve'], {
        'p_post': 'p',
        'p_reply': 'r1',
        'p_remove': true,
      });

      await repo.report('p', reason: ' לא נעים ');
      expect(calls['ba_report'], {
        'p_post': 'p',
        'p_reply': null,
        'p_reason': 'לא נעים',
      });
      await repo.editReply('r1', ' חדש ');
      expect(calls['ba_reply_action'], {
        'p_reply': 'r1',
        'p_action': 'edit',
        'p_text': 'חדש',
      });
      await repo.reject('m');
      expect(calls['ba_reject'], {'p_member': 'm'});
      await repo.removeMember('m');
      expect(calls['ba_remove_member'], {'p_member': 'm'});
      await repo.readUpdates(['n1']);
      expect(calls['ba_read_notifications'], {
        'p_ids': ['n1'],
      });
      expect(await repo.rotateCode(vm.active!), 'NEWCODE2');
      await repo.deleteAccount();
      expect(calls.containsKey('ba_delete_account'), isTrue);
    });

    test('an older server without updates still loads', () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          final legacy = state()..remove('notifications');
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('ba_state') ? legacy : <Object>[],
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final vm = BuildingViewModel(SupabaseBuildingRepository(client));
      addTearDown(vm.dispose);
      await vm.initialize();
      expect(vm.updates, isEmpty);
      expect(vm.active!.id, 'b');
    });
  });

  group('parking', () {
    LocalParkingRepository household(ParkingMemoryStore store, String apartment, String user) =>
        LocalParkingRepository(
          apartmentFor: (_) => apartment,
          userId: user,
          name: user,
          store: store,
        );

    test('a space is edited by its household only', () async {
      final store = ParkingMemoryStore();
      final owner = household(store, '12', 'owner');
      final other = household(store, '8', 'other');
      await owner.addSpace('b', '42', '', '');
      await other.addSpace('b', '7', '', '');
      final space = (await owner.load('b')).spaces.single;
      expect(other.updateSpace(space.id, '50', '', ''), throwsStateError);
      expect(owner.updateSpace(space.id, '7', '', ''), throwsStateError);
      await owner.updateSpace(space.id, ' 43 ', '-2', 'ליד המחסן');
      final saved = (await owner.load('b')).spaces.single;
      expect(saved.label, '43');
      expect(saved.level, '-2');
      expect(saved.notes, 'ליד המחסן');
    });

    test('a series publishes every window or none', () async {
      final owner = household(ParkingMemoryStore(), '12', 'owner');
      await owner.addSpace('b', '42', '', '');
      final space = (await owner.load('b')).spaces.single;
      final start = DateTime.now().add(const Duration(days: 1));
      ParkingWindow day(int i, {int hours = 2}) => (
        start: start.add(Duration(days: i)),
        end: start.add(Duration(days: i, hours: hours)),
      );
      await owner.publishSeries(space.id, [day(0), day(1), day(2)]);
      expect((await owner.load('b')).offers, hasLength(3));
      await expectLater(
        owner.publishSeries(space.id, [day(5), day(1)]),
        throwsStateError,
      );
      expect((await owner.load('b')).offers, hasLength(3));
      await expectLater(owner.publishSeries(space.id, []), throwsStateError);
    });

    test('removing a space withdraws open windows and keeps history', () async {
      final store = ParkingMemoryStore();
      final owner = household(store, '12', 'owner');
      final guest = household(store, '8', 'guest');
      await owner.addSpace('b', '42', '', '');
      final space = (await owner.load('b')).spaces.single;
      final start = DateTime.now().add(const Duration(hours: 1));
      await owner.publish(space.id, start, start.add(const Duration(hours: 1)));
      final offer = (await guest.load('b')).offers.single;
      await guest.book(offer.id);
      await expectLater(owner.removeSpace(space.id), throwsStateError);
      await guest.cancel(offer.id);
      expect(guest.removeSpace(space.id), throwsStateError);
      await owner.removeSpace(space.id);
      expect((await owner.load('b')).spaces, isEmpty);
      expect((await guest.load('b')).offers.where((o) => o.canBook), isEmpty);
      expect((await owner.history('b')).single.status, 'cancelled');
      expect((await guest.history('b')).single.bookingStatus, 'cancelled');
      await owner.addSpace('b', '42', '', '');
      expect((await owner.load('b')).spaces.single.label, '42');
    });
  });

  group('screens', () {
    testWidgets('a post by a neighbour can be reported and disappears', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = LocalBuildingRepository();
      final vm = BuildingViewModel(repo)
        ..enter()
        ..navigate(1);
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('board-post-help'));
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('אפשרויות פרסום')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('דיווח והסתרה'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report-reason')), 'לא מתאים');
      await tester.tap(find.byKey(const Key('report-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('board-post-help')), findsNothing);
      expect((await repo.reports('garden')).single.reasons, ['לא מתאים']);
    });

    testWidgets('own posts offer no report action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final vm = BuildingViewModel(LocalBuildingRepository())
        ..enter()
        ..navigate(1);
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      final card = find.byKey(const Key('board-post-mine'));
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('אפשרויות פרסום')),
      );
      await tester.pumpAndSettle();
      expect(find.text('דיווח והסתרה'), findsNothing);
      expect(find.text('עריכת פרסום'), findsOneWidget);
    });

    testWidgets('a manager declines a request from the updates sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = InboxRepository();
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      expect(vm.inbox, hasLength(1));
      await tester.tap(find.byKey(const Key('building-updates')));
      await tester.pumpAndSettle();
      final decline = find.byKey(const ValueKey('application-reject-request'));
      await tester.ensureVisible(decline);
      await tester.pumpAndSettle();
      await tester.tap(decline);
      await tester.pumpAndSettle();
      expect(find.text('לדחות את הבקשה של רון לוי?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('application-reject-confirm')));
      await tester.pumpAndSettle();
      expect(repo.rejected, ['request']);
      expect(find.byKey(const ValueKey('application-reject-request')), findsNothing);
    });

    testWidgets('search lists matching posts with their replies', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        page(
          BoardSearch(
            repository: LocalBuildingRepository(),
            buildingId: 'garden',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('board-search-post-mine')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('board-search-query')),
        'מקדחה',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('board-search-post-help')), findsOneWidget);
      expect(find.byKey(const ValueKey('board-search-post-mine')), findsNothing);
      expect(find.textContaining('מוזמן לעלות לדירה 8'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('board-search-query')),
        'אין כזה',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(find.text('לא נמצאו פרסומים מתאימים.'), findsOneWidget);
    });

    testWidgets('account deletion appears only where it is available', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        page(
          ProfileEditor(
            profile: const ResidentProfile(name: 'דנה כהן'),
            onSave: (_, _) async {},
          ),
        ),
      );
      expect(find.byKey(const Key('account-delete')), findsNothing);
      await tester.pumpWidget(
        page(
          ProfileEditor(
            profile: const ResidentProfile(name: 'דנה כהן'),
            onSave: (_, _) async {},
            onDelete: () => asked++,
          ),
        ),
      );
      final delete = find.byKey(const Key('account-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      expect(asked, 1);
    });
  });
}
