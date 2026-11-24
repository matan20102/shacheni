import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_repository.dart';
import 'platform_repository.dart';
import 'committee_repository.dart';
import 'parking_repository.dart';
export 'building_error.dart' show buildingErrorMessage;

class SupabaseBuildingRepository implements BuildingRepository {
  SupabaseBuildingRepository(this.client, {this.realtime = false});
  final SupabaseClient client;

  /// Subscribes to the building signal. Off unless the app owns a live client.
  final bool realtime;
  @override
  late final ParkingRepository parking = SupabaseParkingRepository(client);
  @override
  late final CommitteeRepository committee = SupabaseCommitteeRepository(
    client,
  );
  @override
  bool isPlatformAdmin = false;
  @override
  late final PlatformRepository platform = SupabasePlatformRepository(client);
  @override
  Future<List<ResidentMember>> residents(String buildingId) async =>
      List.unmodifiable([
        for (final j in await client.rpc(
          'ba_residents',
          params: {'p_building': buildingId},
        ) as List)
          ResidentMember(
            id: j['id'] as String,
            name: j['name'] as String,
            apartment: j['apartment'] as String,
            household: j['household'] as String,
            isAdmin: j['is_admin'] == true,
            isApartmentAdmin: j['is_apartment_admin'] == true,
            mine: j['mine'] == true,
          ),
      ]);
  @override
  Future<void> setAdmin(String memberId, bool admin) => client.rpc(
    'ba_set_admin',
    params: {'p_member': memberId, 'p_admin': admin},
  );
  @override
  ResidentProfile profile = const ResidentProfile();
  @override
  Object? boardError;
  List<BuildingHome> _homes = const [];
  List<JoinApplication> _applications = const [];
  List<ApprovalUpdate> _approvalUpdates = const [];
  List<BuildingUpdate> _notes = const [];
  final _boards = <String, List<BoardPost>>{};
  int _refreshVersion = 0;
  @override
  bool get isRemote => true;
  @override
  List<BuildingHome> get homes => _homes;
  @override
  List<JoinApplication> get applications => _applications;
  @override
  List<ApprovalUpdate> get approvalUpdates => _approvalUpdates;
  @override
  Future<void> readApprovalUpdates(List<String> ids) =>
      client.rpc('ba_read_approval_updates', params: {'p_ids': ids});
  @override
  List<BoardPost> posts(String buildingId) => _boards[buildingId] ?? const [];

  static BuildingHome homeFromJson(Map<String, dynamic> j) => BuildingHome(
    id: j['id'] as String,
    name: j['name'] as String,
    address: j['address'] as String,
    code: (j['code'] as String?) ?? '',
    apartment: (j['apartment'] as String?) ?? '',
    entrances: (j['entrances'] as int?) ?? 1,
    isAdmin: j['is_admin'] == true,
    isCommittee: j['is_committee'] == true,
    isApartmentAdmin: j['is_apartment_admin'] == true,
    householdName: (j['household_name'] as String?) ?? '',
    entrance: j['entrance'] as String?,
    openReports: (j['open_reports'] as num?)?.toInt() ?? 0,
  );
  static JoinApplication applicationFromJson(Map<String, dynamic> j) =>
      JoinApplication(
        id: j['id'] as String,
        building: BuildingHome(
          id: j['building_id'] as String,
          name: j['building_name'] as String,
          address: j['building_address'] as String,
          code: '',
          apartment: '',
        ),
        apartment: j['apartment'] as String,
        floor: j['floor'] as String?,
        entrance: j['entrance'] as String?,
        apartmentHasAdmin: j['apartment_has_admin'] == true,
        buildingApproved: j['building_approved'] == true,
        apartmentApproved: j['apartment_approved'] == true,
        mine: j['mine'] == true,
        applicantName: (j['applicant_name'] as String?) ?? '',
        canApproveBuilding: j['can_approve_building'] == true,
        canApproveApartment: j['can_approve_apartment'] == true,
      );
  static BoardPost postFromJson(Map<String, dynamic> j) => BoardPost(
    id: j['id'] as String,
    buildingId: j['building_id'] as String,
    author: j['mine'] == true ? 'אני' : j['author'] as String,
    apartment: j['apartment'] as String,
    text: j['text'] as String,
    kind: j['kind'] == 'request' ? PostKind.request : PostKind.notice,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    mine: j['mine'] == true,
    pinned: j['pinned'] == true,
    closed: j['closed'] == true,
    edited: j['edited'] == true,
    replies: List.unmodifiable([
      for (final r in j['replies'] as List)
        BoardReply(
          r['author'] as String,
          r['text'] as String,
          mine: r['mine'] == true,
          id: (r['id'] as String?) ?? '',
          edited: r['edited'] == true,
        ),
    ]),
    reactions: Map.unmodifiable({
      for (final e in (j['reactions'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    }),
    myReactions: Set.unmodifiable((j['my_reactions'] as List).cast<String>()),
    images: List.unmodifiable(
      (j['images'] as List? ?? const []).cast<String>(),
    ),
  );

  @override
  Future<void> refresh({String? buildingId}) async {
    final version = ++_refreshVersion;
    final state = await client.rpc('ba_state') as Map<String, dynamic>;
    final account = state['profile'] as Map<String, dynamic>?;
    final nextProfile = ResidentProfile(
      name: account?['full_name'] as String? ?? '',
      email: account?['email'] as String? ?? '',
      phone: account?['phone'] as String? ?? '',
    );
    final nextHomes = List<BuildingHome>.unmodifiable([
      for (final j in state['homes'] as List)
        homeFromJson(j as Map<String, dynamic>),
    ]);
    final nextApplications = List<JoinApplication>.unmodifiable([
      for (final j in state['applications'] as List)
        applicationFromJson(j as Map<String, dynamic>),
    ]);
    final nextUpdates = List<ApprovalUpdate>.unmodifiable([
      for (final j in (state['approval_updates'] as List? ?? const []))
        if (nextHomes.any((home) => home.id == j['building_id']))
          ApprovalUpdate(
            id: j['id'] as String,
            buildingId: j['building_id'] as String,
            buildingName: j['building_name'] as String,
          ),
    ]);
    final nextNotes = List<BuildingUpdate>.unmodifiable([
      for (final j in (state['notifications'] as List? ?? const []))
        BuildingUpdate(
          id: j['id'] as String,
          type: j['type'] as String,
          buildingId: j['building_id'] as String,
          buildingName: (j['building_name'] as String?) ?? '',
          text: (j['text'] as String?) ?? '',
          startsAt: j['starts_at'] == null
              ? null
              : DateTime.parse(j['starts_at'] as String).toLocal(),
        ),
    ]);
    final selected =
        nextHomes.where((h) => h.id == buildingId).firstOrNull ??
        nextHomes.firstOrNull;
    List<BoardPost>? board;
    Object? nextBoardError;
    if (selected != null) {
      try {
        final response = await client.rpc(
          'ba_board',
          params: {'p_building': selected.id},
        ) as List;
        board = List.unmodifiable([
          for (final j in response) postFromJson(j as Map<String, dynamic>),
        ]);
      } catch (error) {
        // Membership and approval status must still advance if the board fails.
        // Clear the selected cache rather than displaying potentially revoked data.
        nextBoardError = error;
      }
    }
    // A slow response for the previous building must not replace a newer state.
    if (version != _refreshVersion) return;
    _homes = nextHomes;
    isPlatformAdmin = state['is_platform_admin'] == true;
    profile = nextProfile;
    boardError = nextBoardError;
    _applications = nextApplications;
    _approvalUpdates = nextUpdates;
    _notes = nextNotes;
    _boards.removeWhere((id, _) => !_homes.any((h) => h.id == id));
    if (selected != null) _boards[selected.id] = board ?? const [];
  }

  @override
  Future<void> updateProfile(String name, String phone) => client.rpc(
    'ba_update_profile',
    params: {'p_name': name.trim(), 'p_phone': phone.trim()},
  );
  @override
  Future<void> leave(BuildingHome home) =>
      client.rpc('ba_leave', params: {'p_building': home.id});
  @override
  Future<void> archive(BuildingHome home) =>
      client.rpc('ba_archive', params: {'p_building': home.id});

  @override
  Future<BuildingHome> createBuilding(
    String name,
    String address,
    String apartment,
    int entrances, {
    String householdName = '',
    String? entrance,
  }) async {
    final id = await client.rpc(
      'ba_create_home_v2',
      params: {
        'p_address': address.trim(),
        'p_name': name.trim(),
        'p_apartment': apartment.trim(),
        'p_entrances': entrances,
        'p_household_name': householdName.trim(),
        'p_entrance': entrance,
      },
    ) as String;
    await refresh(buildingId: id);
    return homes.firstWhere((h) => h.id == id);
  }

  @override
  Future<void> setHousehold(BuildingHome home, String name) => client.rpc(
    'ba_set_household',
    params: {'p_building': home.id, 'p_name': name.trim()},
  );

  @override
  Future<BuildingHome?> resolveCode(String code) async {
    final value = await client.rpc(
      'ba_resolve',
      params: {'p_code': code.trim()},
    );
    if (value == null) return null;
    final home = homeFromJson(value as Map<String, dynamic>);
    return BuildingHome(
      id: home.id,
      name: home.name,
      address: home.address,
      entrances: home.entrances,
      code: code.trim().toUpperCase(),
      apartment: '',
    );
  }

  @override
  Future<ApartmentStatus> apartmentStatus(
    BuildingHome home,
    String apartment, {
    String? entrance,
  }) async {
    final result = await client.rpc(
      'ba_apartment_status',
      params: {
        'p_code': home.code,
        'p_apartment': normalizeApartment(apartment),
        'p_entrance': entrance,
      },
    ) as Map<String, dynamic>?;
    if (result == null) throw StateError('קוד הבניין אינו תקין');
    return ApartmentStatus(
      exists: result['exists'] == true,
      hasAdmin: result['has_admin'] == true,
    );
  }

  @override
  Future<JoinApplication> apply(
    BuildingHome home,
    String apartment, {
    String? floor,
    String? entrance,
    String householdName = '',
  }) async {
    final id = await client.rpc(
      'ba_apply_home',
      params: {
        'p_code': home.code,
        'p_apartment': normalizeApartment(apartment),
        'p_floor': floor,
        'p_entrance': entrance,
        'p_household_name': householdName.trim(),
      },
    );
    if (id == null) throw StateError('קוד הבניין אינו תקין');
    await refresh();
    return applications.firstWhere((a) => a.id == id);
  }

  @override
  Future<void> approve(String id, {required bool byBuildingAdmin}) async {
    await client.rpc(
      'ba_approve',
      params: {
        'p_member': id,
        'p_role': byBuildingAdmin ? 'building' : 'apartment',
      },
    );
  }

  @override
  Future<void> withdraw(String id) async {
    await client.rpc('ba_withdraw', params: {'p_member': id});
  }

  static const imageBucket = 'board-images';
  final _random = Random.secure();

  // A random version-4 UUID for a new photo's file name.
  String _uuid() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  Future<void> publishWithImages(
    BuildingHome home,
    String text,
    PostKind kind,
    List<PostImage> images,
  ) async {
    if (images.isEmpty) return publish(home, text, kind);
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('יש להתחבר מחדש');
    final bucket = client.storage.from(imageBucket);
    final paths = <String>[];
    try {
      for (final image in images) {
        final path = '${home.id}/$user/${_uuid()}.${image.extension}';
        await bucket.uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(contentType: image.mimeType),
        );
        paths.add(path);
      }
      await client.rpc(
        'ba_publish_v2',
        params: {
          'p_building': home.id,
          'p_body': text.trim(),
          'p_kind': kind.name,
          'p_images': paths,
        },
      );
    } catch (_) {
      // Do not leave photos behind for a post that was not published.
      if (paths.isNotEmpty) {
        try {
          await bucket.remove(paths);
        } catch (_) {
          /* The photos stay unused; the original error matters more. */
        }
      }
      rethrow;
    }
  }

  // Recently shown photos, so scrolling and refreshes do not download again.
  final _imageCache = <String, Future<Uint8List>>{};

  @override
  Future<Uint8List> postImage(String path) {
    final cached = _imageCache.remove(path);
    if (cached != null) return _imageCache[path] = cached;
    if (_imageCache.length >= 60) _imageCache.remove(_imageCache.keys.first);
    final download = client.storage.from(imageBucket).download(path);
    _imageCache[path] = download;
    // A failed download is tried again the next time the photo is shown.
    unawaited(
      download.then((_) {}, onError: (Object _) => _imageCache.remove(path)),
    );
    return download;
  }

  @override
  Future<void> publish(BuildingHome home, String text, PostKind kind) async {
    await client.rpc(
      'ba_publish',
      params: {
        'p_building': home.id,
        'p_body': text.trim(),
        'p_kind': kind.name,
      },
    );
  }

  Future<void> _action(
    String id,
    String action, {
    String? text,
    String? emoji,
  }) async {
    await client.rpc(
      'ba_post_action',
      params: {
        'p_post': id,
        'p_action': action,
        'p_text': text,
        'p_emoji': emoji,
      },
    );
  }

  @override
  Future<void> reply(String id, String text) =>
      _action(id, 'reply', text: text);
  @override
  Future<void> react(String id, String emoji) =>
      _action(id, 'react', emoji: emoji);
  @override
  Future<void> edit(String id, String text) => _action(id, 'edit', text: text);
  @override
  Future<void> close(String id) => _action(id, 'close');
  @override
  Future<void> pin(String id, BuildingHome home) => _action(id, 'pin');
  @override
  Future<void> remove(String id, BuildingHome home) => _action(id, 'delete');

  @override
  List<BuildingUpdate> get updates => _notes;
  @override
  Future<void> readUpdates(List<String> ids) =>
      client.rpc('ba_read_notifications', params: {'p_ids': ids});
  @override
  Future<void> reject(String id) =>
      client.rpc('ba_reject', params: {'p_member': id});
  @override
  Future<void> removeMember(String memberId) =>
      client.rpc('ba_remove_member', params: {'p_member': memberId});
  @override
  Future<void> deleteAccount() => client.rpc('ba_delete_account');
  @override
  Future<String> rotateCode(BuildingHome home) async =>
      await client.rpc('ba_rotate_code', params: {'p_building': home.id})
          as String;
  @override
  Future<void> editReply(String replyId, String text) => client.rpc(
    'ba_reply_action',
    params: {'p_reply': replyId, 'p_action': 'edit', 'p_text': text.trim()},
  );
  @override
  Future<void> removeReply(String replyId) => client.rpc(
    'ba_reply_action',
    params: {'p_reply': replyId, 'p_action': 'delete'},
  );
  @override
  Future<void> report(String postId, {String? replyId, String reason = ''}) =>
      client.rpc(
        'ba_report',
        params: {
          'p_post': postId,
          'p_reply': replyId,
          'p_reason': reason.trim(),
        },
      );
  @override
  Future<List<BoardReport>> reports(String buildingId) async =>
      List.unmodifiable([
        for (final j in await client.rpc(
          'ba_reports',
          params: {'p_building': buildingId},
        ) as List)
          BoardReport(
            postId: j['post_id'] as String,
            replyId: j['reply_id'] as String?,
            text: (j['text'] as String?) ?? '',
            author: (j['author'] as String?) ?? '',
            apartment: (j['apartment'] as String?) ?? '',
            postText: (j['post_text'] as String?) ?? '',
            count: (j['count'] as num?)?.toInt() ?? 1,
            reasons: List.unmodifiable(
              ((j['reasons'] as List?) ?? const []).cast<String>(),
            ),
          ),
      ]);
  @override
  Future<void> resolveReport(BoardReport report, {required bool remove}) =>
      client.rpc(
        'ba_report_resolve',
        params: {
          'p_post': report.postId,
          'p_reply': report.replyId,
          'p_remove': remove,
        },
      );
  @override
  Future<BoardPage> boardPage(
    String buildingId, {
    DateTime? before,
    String query = '',
  }) async {
    final result = await client.rpc(
      'ba_board_page',
      params: {
        'p_building': buildingId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_query': query.trim().isEmpty ? null : query.trim(),
      },
    ) as Map<String, dynamic>;
    return BoardPage(
      List.unmodifiable([
        for (final j in result['posts'] as List)
          postFromJson(j as Map<String, dynamic>),
      ]),
      hasMore: result['has_more'] == true,
    );
  }

  @override
  Stream<void> changes(String buildingId) {
    if (!realtime) return const Stream<void>.empty();
    RealtimeChannel? channel;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        channel = client
            .channel('community-signal-$buildingId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'community_signal',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'building_id',
                value: buildingId,
              ),
              callback: (_) {
                if (!controller.isClosed) controller.add(null);
              },
            )
            .subscribe();
      },
      onCancel: () async {
        final active = channel;
        channel = null;
        if (active != null) await client.removeChannel(active);
        await controller.close();
      },
    );
    return controller.stream;
  }
}
