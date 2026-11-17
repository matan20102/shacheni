import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

import 'building_experience_test.dart' show harness;

/// A building whose board holds more posts than the live board carries.
class LongBoardRepository extends LocalBuildingRepository {
  LongBoardRepository(this.total, {this.failPaging = false});
  final int total;
  bool failPaging;
  int pageRequests = 0;
  late final _board = [
    for (var i = 0; i < total; i++)
      BoardPost(
        id: 'long-${i.toString().padLeft(3, '0')}',
        buildingId: 'garden',
        author: 'שכן',
        apartment: '4',
        text: 'פרסום מספר $i',
        kind: PostKind.notice,
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
        pinned: i == 0,
      ),
  ];
  List<BoardPost> get _ordered => [
    ..._board.where((p) => p.pinned),
    ..._board.where((p) => !p.pinned).toList().reversed,
  ];

  @override
  List<BoardPost> posts(String buildingId) => buildingId == 'garden'
      ? List.unmodifiable(_ordered.take(kLiveBoardLimit))
      : super.posts(buildingId);

  @override
  Future<BoardPage> boardPage(
    String buildingId, {
    DateTime? before,
    String query = '',
  }) async {
    pageRequests++;
    if (failPaging) throw StateError('offline');
    final matches =
        _ordered
            .where((p) => before == null || p.createdAt.isBefore(before))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return BoardPage(matches.take(30).toList(), hasMore: matches.length > 30);
  }

  @override
  void reply(String id, String text) {
    final i = _board.indexWhere((p) => p.id == id);
    if (i < 0) return super.reply(id, text);
    _board[i] = _board[i].copyWith(
      replies: [..._board[i].replies, BoardReply('אני', text, mine: true)],
    );
  }
}

void main() {
  test('local board carries the live limit and pages the rest', () async {
    final repo = LocalBuildingRepository();
    final home = repo.homes.firstWhere((h) => h.id == 'garden');
    for (var i = 0; i < kLiveBoardLimit + 5; i++) {
      repo.publish(home, 'הודעה $i', PostKind.notice);
    }
    expect(repo.posts('garden'), hasLength(kLiveBoardLimit));
    final page = await repo.boardPage('garden');
    expect(page.hasMore, isTrue);
  });

  test('older posts load in pages without duplicates', () async {
    final repo = LongBoardRepository(160);
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    expect(vm.posts, hasLength(100));
    expect(vm.canLoadOlder, isTrue);

    await vm.loadOlder();
    expect(vm.posts, hasLength(130));
    expect(vm.posts.map((p) => p.id).toSet(), hasLength(130));
    expect(vm.canLoadOlder, isTrue);

    await vm.loadOlder();
    expect(vm.posts, hasLength(160));
    // Only the old pinned post remains below; the server cannot know that.
    await vm.loadOlder();
    expect(vm.posts, hasLength(160));
    expect(vm.canLoadOlder, isFalse);
    // Newest first, and the old pinned post appears once.
    expect(vm.posts.first.id, 'long-159');
    expect(vm.posts.where((p) => p.id == 'long-000'), hasLength(1));
  });

  test('a short board never offers older posts', () {
    final vm = BuildingViewModel(LongBoardRepository(40))..enter();
    addTearDown(vm.dispose);
    expect(vm.canLoadOlder, isFalse);
  });

  test('a reply on an older post shows after the change', () async {
    final repo = LongBoardRepository(140);
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    await vm.loadOlder();
    expect(vm.posts.any((p) => p.id == 'long-020'), isTrue);
    await vm.run(() => repo.reply('long-020', 'עדיין רלוונטי?'));
    final post = vm.posts.firstWhere((p) => p.id == 'long-020');
    expect(post.replies.single.text, 'עדיין רלוונטי?');
    expect(vm.posts, hasLength(130));
  });

  testWidgets('board offers older posts at the top and loads them', (
    tester,
  ) async {
    final repo = LongBoardRepository(125);
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    vm.navigate(1);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('board-load-older'));
    await tester.scrollUntilVisible(
      button,
      -400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final anchor = find.textContaining('פרסום מספר 26').first;
    final before = tester.getTopLeft(anchor).dy;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(vm.posts, hasLength(125));
    // The post at the top stays where it was; older ones appear above it.
    expect(tester.getTopLeft(anchor).dy, closeTo(before, 60));
    expect(find.byKey(const Key('board-load-older')), findsNothing);
  });

  testWidgets('a failed page keeps the board and tells the resident', (
    tester,
  ) async {
    final repo = LongBoardRepository(130, failPaging: true);
    final vm = BuildingViewModel(repo)..enter();
    addTearDown(vm.dispose);
    vm.navigate(1);
    await tester.pumpWidget(harness(vm));
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('board-load-older'));
    await tester.scrollUntilVisible(
      button,
      -400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('לא הצלחנו לטעון פרסומים קודמים. נסו שוב.'),
      findsOneWidget,
    );
    expect(vm.posts, hasLength(100));
    expect(find.byKey(const Key('board-load-older')), findsOneWidget);
  });
}
