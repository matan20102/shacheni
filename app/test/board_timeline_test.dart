import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/board_read_store.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/features/building/board_timeline.dart';

List<BoardPost> posts(int count) => List.generate(
  count,
  (i) => BoardPost(
    id: 'p${i.toString().padLeft(3, '0')}',
    buildingId: 'b',
    author: 'שכן',
    apartment: '12',
    text: 'מודעה $i',
    kind: PostKind.notice,
    createdAt: DateTime.utc(2026, 10, 1).add(Duration(minutes: i)),
  ),
);

Widget timeline(
  List<BoardPost> items,
  BoardReadStore store, {
  String building = 'b',
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 390,
        height: 600,
        child: BoardTimeline(
          key: ValueKey(building),
          buildingId: building,
          posts: items,
          readStore: store,
          itemBuilder: (post) => SizedBox(
            key: ValueKey(post.id),
            height: post.id.endsWith('5') ? 180 : 110,
            child: Text(post.text),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final count in [1, 3]) {
    testWidgets('$count posts stay at the top even when all are already read', (
      tester,
    ) async {
      final items = posts(count), store = MemoryBoardReadStore();
      await store.save(
        'b',
        BoardReadPosition(items.last.createdAt, items.last.id),
      );
      await tester.pumpWidget(timeline(items, store));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(const ValueKey('board-b')));
      final first = tester.getRect(find.byKey(ValueKey(items.first.id)));
      expect(first.top, closeTo(viewport.top + 2, 2));
      expect(find.byKey(const Key('board-unread-divider')), findsNothing);
      if (count > 1) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey(items.last.id))).dy,
          greaterThan(first.top),
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'a long read board opens at the latest post with context above it',
    (tester) async {
      final items = posts(30), store = MemoryBoardReadStore();
      await tester.pumpWidget(timeline(items, store));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(const ValueKey('board-b')));
      final last = tester.getRect(find.byKey(ValueKey(items.last.id)));
      expect(last.bottom, closeTo(viewport.bottom - 12, 3));
      expect(
        tester.getTopLeft(find.byKey(ValueKey(items[28].id))).dy,
        lessThan(last.top),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'unread divider opens at the first new post and only visible posts become read',
    (tester) async {
      final items = posts(30), store = MemoryBoardReadStore();
      await store.save('b', BoardReadPosition(items[6].createdAt, items[6].id));
      await tester.pumpWidget(timeline(items, store));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(const ValueKey('board-b')));
      final divider = tester.getRect(
        find.byKey(const Key('board-unread-divider')),
      );
      expect(divider.top, closeTo(viewport.top + 2, 3));
      expect(
        tester.getRect(find.byKey(ValueKey(items[7].id))).top,
        greaterThan(divider.top),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      final saved = await store.load('b');
      expect(saved, isNotNull);
      expect(
        saved!.compareTo(BoardReadPosition(items[7].createdAt, items[7].id)),
        greaterThanOrEqualTo(0),
      );
      expect(
        saved.compareTo(BoardReadPosition(items.last.createdAt, items.last.id)),
        lessThan(0),
      );
      expect(find.byKey(const Key('board-unread-divider')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a short board with an unread post still starts at the top', (
    tester,
  ) async {
    final items = posts(3), store = MemoryBoardReadStore();
    await store.save(
      'b',
      BoardReadPosition(items.first.createdAt, items.first.id),
    );
    await tester.pumpWidget(timeline(items, store));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byKey(const ValueKey('board-b')));
    expect(
      tester.getRect(find.byKey(ValueKey(items.first.id))).top,
      closeTo(viewport.top + 2, 2),
    );
    expect(find.byKey(const Key('board-unread-divider')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'unread near the end keeps earlier context instead of blank space below',
    (tester) async {
      final items = posts(30), store = MemoryBoardReadStore();
      await store.save(
        'b',
        BoardReadPosition(items[27].createdAt, items[27].id),
      );
      await tester.pumpWidget(timeline(items, store));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(const ValueKey('board-b')));
      final divider = tester.getRect(
        find.byKey(const Key('board-unread-divider')),
      );
      expect(divider.top, greaterThan(viewport.top));
      expect(divider.bottom, lessThan(viewport.bottom));
      expect(
        tester.getRect(find.byKey(ValueKey(items.last.id))).bottom,
        closeTo(viewport.bottom - 12, 3),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'read positions never regress and stay separate for each building',
    () async {
      final store = MemoryBoardReadStore(), items = posts(3);
      await store.save(
        'a',
        BoardReadPosition(items.last.createdAt, items.last.id),
      );
      await store.save(
        'a',
        BoardReadPosition(items.first.createdAt, items.first.id),
      );
      expect((await store.load('a'))!.postId, items.last.id);
      expect(await store.load('b'), isNull);
    },
  );
}
