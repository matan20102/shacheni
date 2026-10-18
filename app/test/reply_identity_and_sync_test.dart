import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/supabase_building_repository.dart';
import 'package:shacheni_app/features/building/glass_widgets.dart';

import 'building_experience_test.dart' show harness;
import 'supabase_building_repository_test.dart' show post;

const home = BuildingHome(
  id: 'b',
  name: 'Home',
  address: 'Address',
  code: '',
  apartment: '12',
);
JoinApplication request({
  bool mine = false,
  bool building = false,
  bool apartment = false,
  bool buildingRole = false,
  bool apartmentRole = false,
}) => JoinApplication(
  id: 'request',
  building: home,
  apartment: '2',
  apartmentHasAdmin: true,
  mine: mine,
  buildingApproved: building,
  apartmentApproved: apartment,
  canApproveBuilding: buildingRole,
  canApproveApartment: apartmentRole,
);

class SyncRepository extends LocalBuildingRepository {
  SyncRepository(this.requests) : super(seed: false);
  List<JoinApplication> requests;
  int refreshes = 0;
  @override
  bool get isRemote => true;
  @override
  List<JoinApplication> get applications => requests;
  @override
  Future<void> refresh({String? buildingId}) async {
    refreshes++;
  }
}

class ReplyRepository extends LocalBuildingRepository {
  final created = DateTime.now();
  @override
  List<BoardPost> posts(String id) => [
    BoardPost(
      id: 'identity',
      buildingId: id,
      author: 'Neighbor',
      apartment: '2',
      text: 'שיחת בדיקה',
      kind: PostKind.notice,
      createdAt: created,
      replies: const [
        BoardReply('שם משותף', 'תגובה שלי', mine: true),
        BoardReply('שם משותף', 'תגובה של שכן'),
        BoardReply('אני', 'שם אינו זהות'),
      ],
    ),
  ];
}

void main() {
  test(
    'reply parser uses the server flag and safely accepts an older response',
    () {
      final json = post('b')
        ..['replies'] = [
          {'author': 'Same name', 'text': 'Own', 'mine': true},
          {'author': 'Same name', 'text': 'Other', 'mine': false},
          {'author': 'אני', 'text': 'Name collision', 'mine': false},
          {'author': 'אני', 'text': 'Old response'},
        ];
      json['reactions'] = <String, dynamic>{};
      final replies = SupabaseBuildingRepository.postFromJson(json).replies;
      expect(replies.map((r) => r.mine), [true, false, false, false]);
      expect(replies.first.author, 'Same name');
    },
  );
  test('local replies explicitly identify the author', () {
    final repo = LocalBuildingRepository();
    final id = repo.posts('garden').first.id;
    repo.reply(id, 'תגובה שלי');
    expect(
      repo.posts('garden').firstWhere((p) => p.id == id).replies.last.mine,
      isTrue,
    );
  });
  testWidgets(
    'conversation colors replies by identity despite equal or misleading names',
    (tester) async {
      final vm = BuildingViewModel(ReplyRepository())
        ..enter()
        ..navigate(1);
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 תגובות'));
      await tester.pumpAndSettle();
      GlassPanel panel(String text) => tester.widget<GlassPanel>(
        find
            .ancestor(of: find.text(text), matching: find.byType(GlassPanel))
            .first,
      );
      expect(panel('תגובה שלי').tint, const Color(0xFFD8F0ED));
      expect(panel('תגובה של שכן').tint, Colors.white);
      expect(panel('שם אינו זהות').tint, Colors.white);
      expect(tester.takeException(), isNull);
    },
  );

  final cases = [
    (
      name: 'own request waiting for the apartment',
      app: request(mine: true, building: true),
      fast: true,
      badge: 0,
    ),
    (
      name: 'building manager can approve',
      app: request(buildingRole: true),
      fast: true,
      badge: 1,
    ),
    (
      name: 'apartment manager can approve',
      app: request(building: true, apartmentRole: true),
      fast: true,
      badge: 1,
    ),
    (
      name: 'building manager already approved',
      app: request(building: true, buildingRole: true),
      fast: false,
      badge: 0,
    ),
    (
      name: 'apartment manager already approved',
      app: request(apartment: true, apartmentRole: true),
      fast: false,
      badge: 0,
    ),
    (
      name: 'fully approved request',
      app: request(
        building: true,
        apartment: true,
        buildingRole: true,
        apartmentRole: true,
      ),
      fast: false,
      badge: 0,
    ),
  ];
  for (final scenario in cases) {
    testWidgets('poll timing: ${scenario.name}', (tester) async {
      final repo = SyncRepository([scenario.app]);
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      expect(vm.notificationCount, scenario.badge);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, scenario.fast ? 1 : 0);
      if (!scenario.fast) {
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(repo.refreshes, 1);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'polling reacts to a new actionable request without restarting the screen',
    (tester) async {
      final repo = SyncRepository([
        request(building: true, buildingRole: true),
      ]);
      final vm = BuildingViewModel(repo)..enter();
      addTearDown(vm.dispose);
      await tester.pumpWidget(harness(vm));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, 0);
      repo.requests = [request(building: true, apartmentRole: true)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, 1);
      repo.requests = [];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(repo.refreshes, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
