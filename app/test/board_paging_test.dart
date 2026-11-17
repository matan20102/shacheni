import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

/// A server-like board: the live list holds only the newest 100 posts and
/// older ones come a page at a time.
class LongBoardRepository extends LocalBuildingRepository {
  LongBoardRepository(int count) {
    final start = DateTime(2026, 1, 1);
    _all = List.unmodifiable([
      for (var i = 0; i < count; i++)
        BoardPost(
          id: 'p$i',
          buildingId: homes.first.id,
          author: 'שכן',
          apartment: '1',
          text: 'פרסום $i',
          kind: PostKind.notice,
          createdAt: start.add(Duration(minutes: i)),
        ),
    ]);
  }
  late final List<BoardPost> _all;
  int pageCalls = 0;

  List<BoardPost> get _newestFirst =>
      _all.reversed.where((p) => !removed.contains(p.id)).toList();
  final removed = <String>{};

  @override
  List<BoardPost> posts(String buildingId) =>
      buildingId == homes.first.id ? _newestFirst.take(100).toList() : [];

  @override
  Future<BoardPage> boardPage(
    String buildingId, {
    DateTime? before,
    String query = '',
  }) async {
    pageCalls++;
    final matches = _newestFirst
        .where((p) => before == null || p.createdAt.isBefore(before))
        .toList();
    return BoardPage(matches.take(30).toList(), hasMore: matches.length > 30);
  }
}

void main() {
  test('a short board offers no older posts', () {
    final vm = BuildingViewModel(LongBoardRepository(40));
    expect(vm.posts, hasLength(40));
    expect(vm.mayHaveOlder, isFalse);
  });

  test('older posts load a page at a time until none remain', () async {
    final repo = LongBoardRepository(145);
    final vm = BuildingViewModel(repo);
    expect(vm.posts, hasLength(100));
    expect(vm.mayHaveOlder, isTrue);

    await vm.loadOlder();
    expect(vm.posts, hasLength(130));
    expect(vm.posts.last.id, 'p15');
    expect(vm.mayHaveOlder, isTrue);

    await vm.loadOlder();
    expect(vm.posts, hasLength(145));
    expect(vm.posts.last.id, 'p0');
    expect(vm.mayHaveOlder, isFalse);
    expect(vm.posts.map((p) => p.id).toSet(), hasLength(145));
  });

  test('an action reloads the older posts already shown', () async {
    final repo = LongBoardRepository(145);
    final vm = BuildingViewModel(repo);
    await vm.loadOlder();
    expect(vm.posts.map((p) => p.id), contains('p20'));

    repo.removed.add('p20');
    await vm.run(() {});
    expect(vm.posts.map((p) => p.id), isNot(contains('p20')));
    expect(vm.posts.length, greaterThanOrEqualTo(129));
  });
}
