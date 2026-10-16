import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/supabase_building_repository.dart';

Map<String, dynamic> home(String id) => {
  'id': id,
  'name': id,
  'address': 'Address',
  'apartment': '1',
  'code': '',
  'is_admin': false,
  'is_committee': false,
  'is_apartment_admin': false,
};
Map<String, dynamic> post(String building) => {
  'id': 'post-$building',
  'building_id': building,
  'author': 'Neighbor',
  'apartment': '2',
  'text': 'Only $building',
  'kind': 'notice',
  'created_at': '2026-10-13T10:00:00Z',
  'mine': false,
  'pinned': false,
  'closed': false,
  'replies': [],
  'reactions': {},
  'my_reactions': [],
};
http.Response response(Object? value, http.Request request) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

void main() {
  test(
    'approval updates are parsed and acknowledgement survives a fresh load',
    () async {
      var read = false;
      final client = SupabaseClient(
        'https://example.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          final action = request.url.path.split('/').last;
          if (action == 'ba_read_approval_updates') {
            expect((jsonDecode(request.body) as Map)['p_ids'], ['notice']);
            read = true;
            return response(null, request);
          }
          return response(
            action == 'ba_state'
                ? {
                    'homes': [home('approved')],
                    'applications': [],
                    'approval_updates': read
                        ? []
                        : [
                            {
                              'id': 'notice',
                              'building_id': 'approved',
                              'building_name': 'הבית החדש',
                            },
                          ],
                  }
                : [],
            request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseBuildingRepository(client);
      await repository.refresh();
      expect(repository.approvalUpdates.single.buildingName, 'הבית החדש');
      await repository.readApprovalUpdates(['notice']);
      await repository.refresh();
      expect(repository.approvalUpdates, isEmpty);
      final reopened = SupabaseBuildingRepository(client);
      await reopened.refresh();
      expect(reopened.approvalUpdates, isEmpty);
    },
  );
  test(
    'named household creation uses one atomic RPC and maps the shared name',
    () async {
      final commands = <String>[];
      var family = 'משפחת כהן';
      final client = SupabaseClient(
        'https://example.invalid',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          final action = request.url.path.split('/').last;
          if (action == 'ba_create_home_v2') {
            commands.add(action);
            final params = jsonDecode(request.body) as Map;
            expect(params['p_household_name'], family);
            expect(params['p_entrances'], 9);
            return response('named', request);
          }
          if (action == 'ba_set_household') {
            commands.add(action);
            family = (jsonDecode(request.body) as Map)['p_name'] as String;
            return response(null, request);
          }
          return response(
            action == 'ba_state'
                ? {
                    'homes': [
                      {...home('named'), 'household_name': family},
                    ],
                    'applications': [],
                  }
                : [],
            request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseBuildingRepository(client);
      final created = await repository.createBuilding(
        '',
        'הגפן 18',
        '12',
        9,
        householdName: family,
      );
      expect(created.householdName, family);
      expect(commands, ['ba_create_home_v2']);
      await repository.setHousehold(created, 'משפחת לוי');
      await repository.refresh();
      expect(repository.homes.single.householdName, 'משפחת לוי');
    },
  );
  test('a late response for the previous building cannot replace the current board', () async {
    final firstBoardStarted = Completer<void>();
    final releaseFirstBoard = Completer<void>();
    final client = SupabaseClient(
      'https://example.invalid',
      'test-publishable-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('ba_state')) {
          return response({
            'homes': [home('a'), home('b')],
            'applications': [],
          }, request);
        }
        final building = (jsonDecode(request.body) as Map)['p_building'];
        if (building == 'a') {
          firstBoardStarted.complete();
          await releaseFirstBoard.future;
        }
        return response([post(building as String)], request);
      }),
    );
    addTearDown(client.dispose);
    final repository = SupabaseBuildingRepository(client);
    final first = repository.refresh(buildingId: 'a');
    await firstBoardStarted.future;
    await repository.refresh(buildingId: 'b');
    releaseFirstBoard.complete();
    await first;
    expect(repository.posts('b').single.text, 'Only b');
    expect(repository.posts('a'), isEmpty);
  });

  test('revoked membership removes cached posts on refresh', () async {
    var approved = true;
    final client = SupabaseClient(
      'https://example.invalid',
      'test-publishable-key',
      httpClient: MockClient(
        (request) async => request.url.path.endsWith('ba_state')
            ? response({
                'homes': approved ? [home('a')] : [],
                'applications': [],
              }, request)
            : response([post('a')], request),
      ),
    );
    addTearDown(client.dispose);
    final repository = SupabaseBuildingRepository(client);
    await repository.refresh(buildingId: 'a');
    expect(repository.posts('a'), isNotEmpty);
    approved = false;
    await repository.refresh(buildingId: 'a');
    expect(repository.homes, isEmpty);
    expect(repository.posts('a'), isEmpty);
  });

  test(
    'failed command clears busy state and preserves the active building',
    () async {
      final vm = BuildingViewModel(LocalBuildingRepository());
      addTearDown(vm.dispose);
      final original = vm.active!.id;
      await expectLater(
        vm.run(() => throw StateError('failed')),
        throwsStateError,
      );
      expect(vm.busy, isFalse);
      expect(vm.active!.id, original);
    },
  );
}
