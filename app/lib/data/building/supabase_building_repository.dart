import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_repository.dart';

class SupabaseBuildingRepository implements BuildingRepository {
  SupabaseBuildingRepository(this.client);
  final SupabaseClient client;
  List<BuildingHome> _homes = const [];
  List<JoinApplication> _applications = const [];
  List<ApprovalUpdate> _approvalUpdates = const [];
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
    replies: List.unmodifiable([
      for (final r in j['replies'] as List)
        BoardReply(r['author'] as String, r['text'] as String),
    ]),
    reactions: Map.unmodifiable({
      for (final e in (j['reactions'] as Map<String, dynamic>).entries)
        e.key: (e.value as num).toInt(),
    }),
    myReactions: Set.unmodifiable((j['my_reactions'] as List).cast<String>()),
  );

  @override
  Future<void> refresh({String? buildingId}) async {
    final version = ++_refreshVersion;
    final state = await client.rpc('ba_state') as Map<String, dynamic>;
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
    final selected =
        nextHomes.where((h) => h.id == buildingId).firstOrNull ??
        nextHomes.firstOrNull;
    List<BoardPost>? board;
    if (selected != null) {
      final response = await client.rpc(
        'ba_board',
        params: {'p_building': selected.id},
      ) as List;
      board = List.unmodifiable([
        for (final j in response) postFromJson(j as Map<String, dynamic>),
      ]);
    }
    // A slow response for the previous building must not replace a newer state.
    if (version != _refreshVersion) return;
    _homes = nextHomes;
    _applications = nextApplications;
    _approvalUpdates = nextUpdates;
    _boards.removeWhere((id, _) => !_homes.any((h) => h.id == id));
    if (selected != null) _boards[selected.id] = board!;
  }

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
}

String buildingErrorMessage(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is PostgrestException) {
    return switch (error.message) {
      'ACCESS_DENIED' => 'אין הרשאה לפעולה הזאת. נסה לרענן את הבניין.',
      'ALREADY_APPLIED' => 'כבר קיימת חברות או בקשה לבניין הזה.',
      'LEGAL_NOT_ACCEPTED' => 'יש לאשר את תנאי השימוש לפני ההמשך.',
      'RATE_LIMITED' => 'בוצעו יותר מדי ניסיונות. אפשר לנסות שוב מאוחר יותר.',
      'POST_CLOSED' => 'הפרסום נסגר לתגובות.',
      'INVALID_ARGUMENT' => 'יש לבדוק את הפרטים שהזנת.',
      'INVALID_STATE' => 'הבקשה כבר השתנתה. נסה לרענן.',
      _ =>
        error.code == '23505'
            ? 'כבר קיים בניין עם הכתובת והשם האלה.'
            : 'לא הצלחנו להשלים את הפעולה. אפשר לנסות שוב.',
    };
  }
  return 'לא הצלחנו להתחבר כרגע. בדוק את החיבור ונסה שוב.';
}
