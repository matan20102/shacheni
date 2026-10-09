import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

/// The signed-in user's situation, from the `get_my_access` RPC. The router decides on it.
class MyAccess {
  const MyAccess({
    required this.userId,
    required this.legalPending,
    required this.isPlatformAdmin,
    required this.fullName,
    required this.phone,
    required this.membership,
    required this.adminBuildings,
  });

  factory MyAccess.fromJson(Map<String, dynamic> j) {
    final profile = (j['profile'] as Map<String, dynamic>?) ?? const {};
    final m = j['membership'] as Map<String, dynamic>?;
    return MyAccess(
      userId: j['user_id'] as String,
      legalPending: j['legal_pending'] as bool,
      isPlatformAdmin: j['is_platform_admin'] as bool,
      fullName: (profile['full_name'] as String?) ?? '',
      phone: profile['phone'] as String?,
      membership: m == null ? null : Membership.fromJson(m),
      adminBuildings: [
        for (final b in (j['admin_buildings'] as List)) (id: b['id'] as String, name: b['name'] as String, status: b['status'] as String),
      ],
    );
  }

  final String userId;
  final bool legalPending;
  final bool isPlatformAdmin;
  final String fullName;
  final String? phone;
  final Membership? membership;
  final List<({String id, String name, String status})> adminBuildings;

  bool get isBuildingAdmin => adminBuildings.isNotEmpty;

  /// The building the admin screens work on (MVP: one).
  String? get adminBuildingId => adminBuildings.isEmpty ? null : adminBuildings.first.id;
}

class Membership {
  const Membership({
    required this.id,
    required this.status,
    required this.buildingId,
    required this.buildingName,
    required this.buildingAddress,
    required this.apartment,
    required this.infoRequestMessage,
    required this.statusReason,
    required this.spaces,
  });

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
        id: j['id'] as String,
        status: j['status'] as String,
        buildingId: j['building_id'] as String,
        buildingName: j['building_name'] as String,
        buildingAddress: j['building_address'] as String,
        apartment: j['apartment'] as String,
        infoRequestMessage: j['info_request_message'] as String?,
        statusReason: j['status_reason'] as String?,
        spaces: [for (final s in (j['spaces'] as List)) (label: s['label'] as String, status: s['status'] as String)],
      );

  final String id;
  final String status; // pending · info_requested · approved · rejected · withdrawn · disabled
  final String buildingId;
  final String buildingName;
  final String buildingAddress;
  final String apartment;
  final String? infoRequestMessage;
  final String? statusReason;
  final List<({String label, String status})> spaces;
}

class MyAccessNotifier extends Notifier<MyAccess?> {
  @override
  MyAccess? build() => null;

  void set(MyAccess? v) => state = v;
}

/// Filled by the gate after every refresh; null in demo mode or when signed out.
final myAccessProvider = NotifierProvider<MyAccessNotifier, MyAccess?>(MyAccessNotifier.new);

/// A building found by its join code, with the pick-lists for the application form.
class JoinInfo {
  const JoinInfo({required this.buildingId, required this.name, required this.address, required this.apartments, required this.spaces});

  factory JoinInfo.fromJson(Map<String, dynamic> j) {
    final b = j['building'] as Map<String, dynamic>;
    return JoinInfo(
      buildingId: b['id'] as String,
      name: b['name'] as String,
      address: [b['address'], b['city']].whereType<String>().join(', '),
      apartments: [for (final a in (j['apartments'] as List)) (id: a['id'] as String, label: a['number'] as String)],
      spaces: [for (final s in (j['spaces'] as List)) (id: s['id'] as String, label: s['label'] as String)],
    );
  }

  final String buildingId;
  final String name;
  final String address;
  final List<({String id, String label})> apartments;
  final List<({String id, String label})> spaces;
}

class JoinInfoNotifier extends Notifier<JoinInfo?> {
  @override
  JoinInfo? build() => null;

  void set(JoinInfo? v) => state = v;
}

/// Carries the resolved building from the join screen to the application form.
final joinInfoProvider = NotifierProvider<JoinInfoNotifier, JoinInfo?>(JoinInfoNotifier.new);

/// One application as the building admin sees it (`admin_list_applications`).
class AdminApplication {
  const AdminApplication(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get fullName => j['full_name'] as String;
  String get phone => (j['phone'] as String?) ?? '';
  String get apartment => j['apartment'] as String;
  String get status => j['status'] as String;
  bool get isOpen => status == 'pending' || status == 'info_requested';
  DateTime get submittedAt => DateTime.parse(j['submitted_at'] as String).toLocal();
  String? get infoRequestMessage => j['info_request_message'] as String?;
  String? get infoResponse => j['info_response'] as String?;
  String? get statusReason => j['status_reason'] as String?;
  bool get isSelf => j['is_self'] as bool;
  bool get selfReviewed => (j['flags'] as Map<String, dynamic>?)?['self_review'] == true;
  bool get secondResident => (j['apartment_residents'] as num) > 0;
  List<({String spaceId, String label, String status, bool heldByOther})> get spaces => [
        for (final s in (j['spaces'] as List))
          (
            spaceId: s['space_id'] as String,
            label: s['label'] as String,
            status: s['status'] as String,
            heldByOther: s['held_by_other'] as bool,
          ),
      ];
}

/// The join-flow RPCs (see supabase/migrations/…_join_flow.sql).
class MembershipRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<MyAccess> myAccess() async =>
      MyAccess.fromJson((await _db.rpc('get_my_access')) as Map<String, dynamic>);

  /// null = no active building with that code.
  Future<JoinInfo?> resolveJoinCode(String code) async {
    final r = await _db.rpc('resolve_join_code', params: {'p_code': code});
    return r == null ? null : JoinInfo.fromJson(r as Map<String, dynamic>);
  }

  /// Active buildings matching a name / street / city (F37; ≥ 2 characters, ≤ 10 results).
  Future<List<({String id, String name, String address})>> searchBuildings(String query) async => [
        for (final b in (await _db.rpc('search_buildings', params: {'p_query': query})) as List)
          (
            id: b['id'] as String,
            name: b['name'] as String,
            address: [b['address'], b['city']].whereType<String>().join(', '),
          ),
      ];

  Future<JoinInfo> joinInfo(String buildingId) async =>
      JoinInfo.fromJson((await _db.rpc('get_join_info', params: {'p_building': buildingId})) as Map<String, dynamic>);

  Future<void> submitApplication({
    required String buildingId,
    required String apartmentId,
    required List<String> spaceIds,
    required String fullName,
    required String phone,
    required Map<String, bool> declarations,
    required String locale,
  }) =>
      _db.rpc('submit_membership_application', params: {
        'p_building': buildingId,
        'p_apartment': apartmentId,
        'p_space_ids': spaceIds,
        'p_full_name': fullName,
        'p_phone': phone,
        'p_declarations': declarations,
        'p_locale': locale,
      });

  Future<void> withdrawApplication() => _db.rpc('withdraw_application');

  /// Name / phone on the own profile (phone is normalized and checked server-side).
  Future<void> updateProfile({required String fullName, required String phone}) =>
      _db.rpc('update_my_profile', params: {'p_full_name': fullName, 'p_phone': phone});

  /// Moving out: ends parking assignments, cancels open listings/requests (server-side).
  Future<void> leaveBuilding() => _db.rpc('leave_building');

  Future<void> respondToInfoRequest(String text) => _db.rpc('respond_to_info_request', params: {'p_text': text});

  // --- platform ---
  Future<List<Map<String, dynamic>>> platformBuildings() async =>
      ((await _db.rpc('platform_list_buildings')) as List).cast<Map<String, dynamic>>();

  Future<String> createBuilding(String name, String address, String city, int apartments, int spaces) async =>
      (await _db.rpc('create_building', params: {
        'p_name': name,
        'p_address': address,
        'p_city': city,
        'p_apartment_count': apartments,
        'p_parking_count': spaces,
      })) as String;

  Future<void> setUnits(String buildingId, List<String> apartments, List<String> spaces) =>
      _db.rpc('set_building_units', params: {'p_building': buildingId, 'p_apartments': apartments, 'p_spaces': spaces});

  /// Returns the new join code.
  Future<String> activate(String buildingId, String locale) async =>
      (await _db.rpc('accept_building_agreement_and_activate', params: {'p_building': buildingId, 'p_locale': locale}))
          as String;

  // --- building admin ---
  Future<Map<String, dynamic>> adminBuilding(String buildingId) async =>
      (await _db.rpc('admin_get_building', params: {'p_building': buildingId})) as Map<String, dynamic>;

  Future<List<AdminApplication>> adminApplications(String buildingId) async => [
        for (final r in (await _db.rpc('admin_list_applications', params: {'p_building': buildingId})) as List)
          AdminApplication(r as Map<String, dynamic>),
      ];

  /// decision: approve · reject · request_info
  Future<void> decide(String membershipId, String decision, {String? note, List<String> approveSpaceIds = const []}) =>
      _db.rpc('admin_decide_membership', params: {
        'p_membership': membershipId,
        'p_decision': decision,
        'p_note': note,
        'p_approve_space_ids': approveSpaceIds,
      });
}

final membershipRepoProvider = Provider<MembershipRepository>((ref) => MembershipRepository());

/// +972501234567 → 050-123-4567 (how people type it); '' if not an Israeli mobile.
String localPhone(String? e164) {
  if (e164 == null || !e164.startsWith('+972') || e164.length != 13) return '';
  final n = '0${e164.substring(4)}';
  return '${n.substring(0, 3)}-${n.substring(3, 6)}-${n.substring(6)}';
}

/// Server error codes (raised as the message) → localized text.
String errorText(BuildContext context, Object error) {
  final l = AppL10n.of(context);
  final code = error is PostgrestException ? error.message : '';
  return switch (code) {
    'RATE_LIMITED' => l.errRateLimited,
    'PHONE_INVALID' => l.phoneInvalid,
    'PHONE_TAKEN' => l.errPhoneTaken,
    'SPACE_HELD' => l.errSpaceHeld,
    'SELF_REVIEW_FORBIDDEN' => l.errSelfReview,
    'COUNT_MISMATCH' => l.errCountMismatch,
    'DUPLICATE_LABEL' => l.errDuplicateLabel,
    'BUILDING_EXISTS' => l.errBuildingExists,
    'NOTE_REQUIRED' => l.errNoteRequired,
    'ACTIVE_COMMITMENTS' => l.errActiveCommitments,
    _ => l.actionFailed,
  };
}

/// Building name for headers: the real one once a membership exists, else the demo building.
String currentBuildingName(WidgetRef ref, BuildContext context) =>
    ref.watch(myAccessProvider)?.membership?.buildingName ?? ref.watch(demoProvider).data.buildingName.of(context.lang);
