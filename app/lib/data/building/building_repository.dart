import 'dart:async';

import 'package:flutter/foundation.dart';

import 'parking_repository.dart';
import 'local_parking_repository.dart';

import 'board_read_store.dart';
import 'platform_repository.dart';

enum PostKind { notice, request }

@immutable
class ResidentMember {
  const ResidentMember({
    required this.id,
    required this.name,
    required this.apartment,
    this.household = '',
    this.isAdmin = false,
    this.isApartmentAdmin = false,
    this.mine = false,
  });
  final String id, name, apartment, household;
  final bool isAdmin, isApartmentAdmin, mine;
  ResidentMember withAdmin(bool admin) => ResidentMember(
    id: id,
    name: name,
    apartment: apartment,
    household: household,
    isAdmin: admin,
    isApartmentAdmin: isApartmentAdmin,
    mine: mine,
  );
}

@immutable
class ResidentProfile {
  const ResidentProfile({this.name = '', this.email = '', this.phone = ''});
  final String name, email, phone;
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

String normalizeApartment(String value) =>
    value.trim().replaceFirst(RegExp(r'^0+(?=\d)'), '');

@immutable
class ApartmentStatus {
  const ApartmentStatus({required this.exists, required this.hasAdmin});
  final bool exists, hasAdmin;
}

@immutable
class BuildingHome {
  const BuildingHome({
    required this.id,
    required this.name,
    required this.address,
    required this.code,
    required this.apartment,
    this.entrances = 1,
    this.isAdmin = false,
    this.isCommittee = false,
    this.isApartmentAdmin = false,
    this.householdName = '',
    this.entrance,
    this.openReports = 0,
  });
  final String id, name, address, code, apartment;
  final String householdName;
  final String? entrance;
  final int entrances, openReports;
  final bool isAdmin, isCommittee;
  final bool isApartmentAdmin;

  BuildingHome withHouseholdName(String value) =>
      copyWith(householdName: value);
  BuildingHome copyWith({String? householdName, bool? isAdmin, String? code}) =>
      BuildingHome(
        id: id,
        name: name,
        address: address,
        code: code ?? this.code,
        openReports: openReports,
        apartment: apartment,
        entrances: entrances,
        isAdmin: isAdmin ?? this.isAdmin,
        isCommittee: isCommittee,
        isApartmentAdmin: isApartmentAdmin,
        householdName: householdName ?? this.householdName,
        entrance: entrance,
      );
}

@immutable
class BoardReply {
  const BoardReply(
    this.author,
    this.text, {
    this.mine = false,
    this.id = '',
    this.edited = false,
  });
  final String author, text, id;
  final bool mine, edited;
}

/// An unread update for the bell: a decision on a request, a reply, parking.
@immutable
class BuildingUpdate {
  const BuildingUpdate({
    required this.id,
    required this.type,
    required this.buildingId,
    required this.buildingName,
    this.text = '',
    this.startsAt,
  });
  final String id, type, buildingId, buildingName, text;
  final DateTime? startsAt;
}

/// One reported post or reply, as a building manager reviews it.
@immutable
class BoardReport {
  const BoardReport({
    required this.postId,
    required this.text,
    required this.author,
    this.replyId,
    this.apartment = '',
    this.postText = '',
    this.count = 1,
    this.reasons = const [],
  });
  final String postId, text, author, apartment, postText;
  final String? replyId;
  final int count;
  final List<String> reasons;
}

/// How many posts the live board carries (`ba_board` on the server). Older
/// posts come from [BuildingRepository.boardPage].
const kLiveBoardLimit = 100;

@immutable
class BoardPage {
  const BoardPage(this.posts, {this.hasMore = false});
  final List<BoardPost> posts;
  final bool hasMore;
}

@immutable
class BoardPost {
  const BoardPost({
    required this.id,
    required this.buildingId,
    required this.author,
    required this.apartment,
    required this.text,
    required this.kind,
    required this.createdAt,
    this.mine = false,
    this.pinned = false,
    this.closed = false,
    this.edited = false,
    this.replies = const [],
    this.reactions = const {},
    this.myReactions = const {},
  });
  final String id, buildingId, author, apartment, text;
  final PostKind kind;
  final DateTime createdAt;
  final bool mine, pinned, closed, edited;
  final List<BoardReply> replies;
  final Map<String, int> reactions;
  final Set<String> myReactions;

  BoardPost copyWithReplies(Iterable<BoardReply> visible) => BoardPost(
    id: id,
    buildingId: buildingId,
    author: author,
    apartment: apartment,
    text: text,
    kind: kind,
    createdAt: createdAt,
    mine: mine,
    pinned: pinned,
    closed: closed,
    edited: edited,
    replies: List.unmodifiable(visible),
    reactions: reactions,
    myReactions: myReactions,
  );

  BoardPost copyWith({
    String? text,
    bool? pinned,
    bool? closed,
    List<BoardReply>? replies,
    Map<String, int>? reactions,
    Set<String>? myReactions,
  }) => BoardPost(
    id: id,
    buildingId: buildingId,
    author: author,
    apartment: apartment,
    text: text ?? this.text,
    kind: kind,
    createdAt: createdAt,
    mine: mine,
    pinned: pinned ?? this.pinned,
    closed: closed ?? this.closed,
    edited: edited || text != null,
    replies: replies ?? this.replies,
    reactions: reactions ?? this.reactions,
    myReactions: myReactions ?? this.myReactions,
  );
}

@immutable
class ApprovalUpdate {
  const ApprovalUpdate({
    required this.id,
    required this.buildingId,
    required this.buildingName,
  });
  final String id, buildingId, buildingName;
}

@immutable
class JoinApplication {
  const JoinApplication({
    required this.id,
    required this.building,
    required this.apartment,
    required this.apartmentHasAdmin,
    this.floor,
    this.entrance,
    this.buildingApproved = false,
    this.apartmentApproved = false,
    this.mine = true,
    this.applicantName = '',
    this.canApproveBuilding = false,
    this.canApproveApartment = false,
    this.requestedHouseholdName = '',
  });
  final String id, apartment;
  final BuildingHome building;
  final String? floor, entrance;
  final bool apartmentHasAdmin, buildingApproved, apartmentApproved;
  final bool mine, canApproveBuilding, canApproveApartment;
  final String applicantName;
  final String requestedHouseholdName;
  bool get approved =>
      buildingApproved && (!apartmentHasAdmin || apartmentApproved);
  bool get becomesApartmentAdmin => approved && !apartmentHasAdmin;
  bool get needsMyApproval =>
      !approved &&
      ((!buildingApproved && canApproveBuilding) ||
          (apartmentHasAdmin && !apartmentApproved && canApproveApartment));

  JoinApplication copyWith({bool? buildingApproved, bool? apartmentApproved}) =>
      JoinApplication(
        id: id,
        building: building,
        apartment: apartment,
        apartmentHasAdmin: apartmentHasAdmin,
        floor: floor,
        entrance: entrance,
        buildingApproved: buildingApproved ?? this.buildingApproved,
        apartmentApproved: apartmentApproved ?? this.apartmentApproved,
        mine: mine,
        applicantName: applicantName,
        canApproveBuilding: canApproveBuilding,
        canApproveApartment: canApproveApartment,
        requestedHouseholdName: requestedHouseholdName,
      );
}

abstract class BuildingRepository {
  ParkingRepository get parking;
  bool get isPlatformAdmin;
  PlatformRepository? get platform;
  Future<List<ResidentMember>> residents(String buildingId);
  FutureOr<void> setAdmin(String memberId, bool admin);
  ResidentProfile get profile;
  Object? get boardError;
  FutureOr<void> updateProfile(String name, String phone);
  FutureOr<void> leave(BuildingHome home);
  FutureOr<void> archive(BuildingHome home);
  bool get isRemote;
  List<BuildingHome> get homes;
  List<JoinApplication> get applications;
  List<ApprovalUpdate> get approvalUpdates;
  FutureOr<void> readApprovalUpdates(List<String> ids);
  List<BoardPost> posts(String buildingId);
  Future<void> refresh({String? buildingId});
  FutureOr<BuildingHome> createBuilding(
    String name,
    String address,
    String apartment,
    int entrances, {
    String householdName = '',
    String? entrance,
  });
  FutureOr<void> setHousehold(BuildingHome home, String name);
  FutureOr<BuildingHome?> resolveCode(String code);
  FutureOr<ApartmentStatus> apartmentStatus(
    BuildingHome home,
    String apartment, {
    String? entrance,
  });
  FutureOr<JoinApplication> apply(
    BuildingHome home,
    String apartment, {
    String? floor,
    String? entrance,
    String householdName = '',
  });
  FutureOr<void> approve(String id, {required bool byBuildingAdmin});
  FutureOr<void> withdraw(String id);
  FutureOr<void> publish(BuildingHome home, String text, PostKind kind);
  FutureOr<void> reply(String id, String text);
  FutureOr<void> react(String id, String emoji);
  FutureOr<void> edit(String id, String text);
  FutureOr<void> close(String id);
  FutureOr<void> pin(String id, BuildingHome home);
  FutureOr<void> remove(String id, BuildingHome home);

  /// Unread updates other than an accepted request.
  List<BuildingUpdate> get updates;
  FutureOr<void> readUpdates(List<String> ids);
  FutureOr<void> reject(String id);
  FutureOr<void> removeMember(String memberId);
  FutureOr<void> deleteAccount();
  FutureOr<String> rotateCode(BuildingHome home);
  FutureOr<void> editReply(String replyId, String text);
  FutureOr<void> removeReply(String replyId);
  FutureOr<void> report(String postId, {String? replyId, String reason = ''});
  Future<List<BoardReport>> reports(String buildingId);
  FutureOr<void> resolveReport(BoardReport report, {required bool remove});

  /// Older posts and search, newest first; the live board stays on [posts].
  Future<BoardPage> boardPage(
    String buildingId, {
    DateTime? before,
    String query = '',
  });

  /// Emits when something in the building changed on the server.
  Stream<void> changes(String buildingId);
}

/// Repository boundary for the new product. This first adapter deliberately
/// keeps all writes in memory; it never uses or mutates the shared Supabase DB.
class LocalBuildingRepository implements BuildingRepository {
  @override
  late final ParkingRepository parking = LocalParkingRepository(
    apartmentFor: (id) =>
        _homes.where((h) => h.id == id).firstOrNull?.apartment,
  );
  @override
  bool get isPlatformAdmin => false;
  @override
  PlatformRepository? get platform => null;
  final _directories = <String, List<ResidentMember>>{};
  @override
  Future<List<ResidentMember>> residents(String buildingId) async {
    final home = _homes.firstWhere((h) => h.id == buildingId);
    final rows = _directories.putIfAbsent(
      buildingId,
      () => [
        ResidentMember(
          id: 'neighbor-2-$buildingId',
          name: 'דנה לוי',
          apartment: '2',
          isApartmentAdmin: true,
        ),
        ResidentMember(
          id: 'self-$buildingId',
          name: profile.name.isEmpty ? 'אני' : profile.name,
          apartment: home.apartment,
          mine: true,
          isAdmin: home.isAdmin,
          isApartmentAdmin: home.isApartmentAdmin,
        ),
        ResidentMember(
          id: 'neighbor-20-$buildingId',
          name: 'יואב כהן',
          apartment: '20',
          isApartmentAdmin: true,
        ),
      ],
    );
    rows.sort((a, b) {
      final apartment = BigInt.parse(a.apartment)
          .compareTo(BigInt.parse(b.apartment));
      if (apartment != 0) return apartment;
      return a.isApartmentAdmin == b.isApartmentAdmin
          ? a.id.compareTo(b.id)
          : a.isApartmentAdmin
          ? -1
          : 1;
    });
    return List.unmodifiable(rows);
  }

  @override
  void setAdmin(String memberId, bool admin) {
    final entry = _directories.entries.firstWhere(
      (e) => e.value.any((m) => m.id == memberId),
    );
    final home = _homes.firstWhere((h) => h.id == entry.key);
    if (!home.isAdmin) throw StateError('אין הרשאה');
    final index = entry.value.indexWhere((m) => m.id == memberId);
    final member = entry.value[index];
    if (!admin &&
        member.isAdmin &&
        entry.value.where((m) => m.isAdmin).length == 1) {
      throw StateError(
        'מנהל הבניין האחרון צריך למנות מחליף או לארכב את הבניין לפני היציאה.',
      );
    }
    entry.value[index] = member.withAdmin(admin);
    if (member.mine) {
      _homes[_homes.indexOf(home)] = home.copyWith(isAdmin: admin);
    }
  }

  @override
  ResidentProfile profile = const ResidentProfile();
  @override
  Object? get boardError => null;
  @override
  void updateProfile(String name, String phone) {
    if (name.trim().length < 2 || name.trim().length > 100) {
      throw StateError('יש להזין שם באורך 2–100 תווים');
    }
    profile = ResidentProfile(
      name: name.trim(),
      phone: phone.trim(),
      email: profile.email,
    );
  }

  @override
  void leave(BuildingHome home) {
    if (!_homes.contains(home)) throw StateError('אין גישה לבניין');
    if (home.isAdmin &&
        (_directories[home.id]?.where((m) => m.isAdmin).length ?? 1) == 1) {
      throw StateError(
        'מנהל הבניין האחרון צריך למנות מחליף או לארכב את הבניין לפני היציאה.',
      );
    }
    _removeHome(home);
  }

  @override
  void archive(BuildingHome home) {
    if (!_homes.contains(home) || !home.isAdmin) throw StateError('אין הרשאה');
    _removeHome(home);
  }

  final _updates = <BuildingUpdate>[];
  final _reports = <BoardReport>[];
  final _hiddenPosts = <String>{}, _hiddenReplies = <String>{};
  @override
  List<BuildingUpdate> get updates => List.unmodifiable(_updates);
  @override
  void readUpdates(List<String> ids) =>
      _updates.removeWhere((update) => ids.contains(update.id));

  @override
  void reject(String id) {
    final index = _applications.indexWhere((a) => a.id == id && !a.approved);
    if (index < 0) throw StateError('הבקשה כבר השתנתה. נסה לרענן.');
    _applications.removeAt(index);
  }

  @override
  void removeMember(String memberId) {
    final entry = _directories.entries.firstWhere(
      (e) => e.value.any((m) => m.id == memberId),
    );
    final home = _homes.firstWhere((h) => h.id == entry.key);
    if (!home.isAdmin) throw StateError('אין הרשאה');
    final member = entry.value.firstWhere((m) => m.id == memberId);
    if (member.mine) throw StateError('כדי לעזוב משתמשים ביציאה מהבניין.');
    if (member.isAdmin) {
      throw StateError('יש להסיר קודם את הרשאת ניהול הבניין.');
    }
    entry.value.remove(member);
  }

  @override
  void deleteAccount() {
    _homes.clear();
    _applications.clear();
    _approvalUpdates.clear();
    _updates.clear();
    _posts.removeWhere((p) => p.mine);
    profile = const ResidentProfile();
  }

  @override
  String rotateCode(BuildingHome home) {
    final index = _homes.indexWhere((h) => h.id == home.id);
    if (index < 0 || !_homes[index].isAdmin) throw StateError('אין הרשאה');
    final code =
        'SH${_id('code').hashCode.abs().toRadixString(36).toUpperCase()}';
    _homes[index] = _homes[index].copyWith(code: code);
    return code;
  }

  BoardPost _postOfReply(String replyId) => _posts.firstWhere(
    (p) => replyId.isNotEmpty && p.replies.any((r) => r.id == replyId),
    orElse: () => throw StateError('התגובה לא נמצאה'),
  );

  @override
  void editReply(String replyId, String text) {
    final post = _postOfReply(replyId);
    if (text.trim().isEmpty || text.trim().length > 1000) {
      throw ArgumentError('תגובה לא תקינה');
    }
    _update(
      post.id,
      (p) => p.copyWith(
        replies: List.unmodifiable([
          for (final r in p.replies)
            if (r.id != replyId)
              r
            else if (!r.mine)
              throw StateError('אין הרשאה')
            else
              BoardReply(
                r.author,
                text.trim(),
                mine: true,
                id: r.id,
                edited: true,
              ),
        ]),
      ),
    );
  }

  @override
  void removeReply(String replyId) {
    final post = _postOfReply(replyId);
    final reply = post.replies.firstWhere((r) => r.id == replyId);
    final home = _homes.where((h) => h.id == post.buildingId).firstOrNull;
    if (!reply.mine && !(home?.isAdmin ?? false)) throw StateError('אין הרשאה');
    _update(
      post.id,
      (p) => p.copyWith(
        replies: List.unmodifiable(p.replies.where((r) => r.id != replyId)),
      ),
    );
    _reports.removeWhere((r) => r.replyId == replyId);
  }

  @override
  void report(String postId, {String? replyId, String reason = ''}) {
    final post = _posts.firstWhere((p) => p.id == postId);
    if (!_homes.any((h) => h.id == post.buildingId)) {
      throw StateError('אין גישה לבניין');
    }
    if (reason.trim().length > 300) throw ArgumentError('הסבר ארוך מדי');
    final reply = replyId == null
        ? null
        : post.replies.firstWhere((r) => r.id == replyId);
    if (reply?.mine ?? post.mine) {
      throw StateError('אי אפשר לדווח על תוכן שכתבת.');
    }
    if (replyId == null
        ? !_hiddenPosts.add(postId)
        : !_hiddenReplies.add(replyId)) {
      return;
    }
    _reports.add(
      BoardReport(
        postId: postId,
        replyId: replyId,
        text: reply?.text ?? post.text,
        author: reply?.author ?? post.author,
        apartment: post.apartment,
        postText: post.text,
        reasons: [if (reason.trim().isNotEmpty) reason.trim()],
      ),
    );
  }

  @override
  Future<List<BoardReport>> reports(String buildingId) async {
    final home = _homes.where((h) => h.id == buildingId).firstOrNull;
    if (home == null || !home.isAdmin) throw StateError('אין הרשאה');
    return List.unmodifiable(
      _reports.where(
        (r) =>
            _posts.any((p) => p.id == r.postId && p.buildingId == buildingId),
      ),
    );
  }

  @override
  void resolveReport(BoardReport report, {required bool remove}) {
    final post = _posts.where((p) => p.id == report.postId).firstOrNull;
    final home = _homes.where((h) => h.id == post?.buildingId).firstOrNull;
    if (post == null || home == null || !home.isAdmin) {
      throw StateError('אין הרשאה');
    }
    if (remove && report.replyId == null) {
      _posts.remove(post);
      _reports.removeWhere((r) => r.postId == report.postId);
    } else if (remove) {
      _update(
        post.id,
        (p) => p.copyWith(
          replies: List.unmodifiable(
            p.replies.where((r) => r.id != report.replyId),
          ),
        ),
      );
    }
    _reports.removeWhere(
      (r) => r.postId == report.postId && r.replyId == report.replyId,
    );
  }

  @override
  Future<BoardPage> boardPage(
    String buildingId, {
    DateTime? before,
    String query = '',
  }) async {
    const size = 30;
    final q = query.trim().toLowerCase();
    final matches =
        _visiblePosts(buildingId)
            .where(
              (p) =>
                  (before == null || p.createdAt.isBefore(before)) &&
                  (q.isEmpty ||
                      p.text.toLowerCase().contains(q) ||
                      p.replies.any((r) => r.text.toLowerCase().contains(q))),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return BoardPage(
      List.unmodifiable(matches.take(size)),
      hasMore: matches.length > size,
    );
  }

  @override
  Stream<void> changes(String buildingId) => const Stream<void>.empty();

  void _removeHome(BuildingHome home) {
    _homes.remove(home);
    _applications.removeWhere((a) => a.building.id == home.id);
    _approvalUpdates.removeWhere((a) => a.buildingId == home.id);
  }

  LocalBuildingRepository({bool seed = true}) {
    if (!seed) return;
    _homes.addAll(const [
      BuildingHome(
        id: 'garden',
        name: 'הבית בגינה',
        address: 'הגפן 18, רמת גן',
        code: 'GARDEN18',
        apartment: '12',
        entrances: 2,
        isAdmin: true,
        isCommittee: true,
      ),
      BuildingHome(
        id: 'olive',
        name: 'בית הזית',
        address: 'הזית 7, גבעתיים',
        code: 'OLIVE7',
        apartment: '4',
      ),
    ]);
    final now = DateTime.now();
    _posts.addAll([
      BoardPost(
        id: 'notice',
        buildingId: 'garden',
        author: 'מיכל · ועד הבית',
        apartment: '8',
        text: 'קצת ירוק בכניסה 🌿\nביום שישי ב־10:00 נשתול יחד עציצים חדשים. מוזמנים לרדת לקפה ולהביא את הילדים!',
        kind: PostKind.notice,
        createdAt: now.subtract(const Duration(hours: 2)),
        pinned: true,
        replies: const [BoardReply('דנה', 'איזה כיף, אנחנו מגיעים!')],
        reactions: const {'💚': 6, '🙌': 3},
      ),
      BoardPost(
        id: 'help',
        buildingId: 'garden',
        author: 'אורי',
        apartment: '6',
        text: 'יש למישהו מקדחה להשאיל לחצי שעה?\nמבטיח להחזיר עם שוקולד 🍫',
        kind: PostKind.request,
        createdAt: now.subtract(const Duration(minutes: 45)),
        replies: const [BoardReply('מיכל', 'יש אצלנו, מוזמן לעלות לדירה 8.')],
        reactions: const {'🙌': 2},
      ),
      BoardPost(
        id: 'mine',
        buildingId: 'garden',
        author: 'אני',
        apartment: '12',
        text: 'תודה לשכנים שעזרו עם החבילה אתמול. איזה כיף לגור פה 💚',
        kind: PostKind.notice,
        createdAt: now.subtract(const Duration(minutes: 18)),
        mine: true,
        reactions: const {'💚': 4},
      ),
      BoardPost(
        id: 'resolved',
        buildingId: 'garden',
        author: 'נועה',
        apartment: '3',
        text: 'מישהו ראה מפתחות ליד המעלית?\nעדכון: נמצאו, תודה לכולם!',
        kind: PostKind.request,
        createdAt: now.subtract(const Duration(days: 1)),
        closed: true,
      ),
    ]);
  }
  final _homes = <BuildingHome>[];
  @override
  bool get isRemote => false;
  @override
  Future<void> refresh({String? buildingId}) async {}
  final _posts = <BoardPost>[];
  final _applications = <JoinApplication>[];
  final _approvalUpdates = <ApprovalUpdate>[];
  int _sequence = 0;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  @override
  List<BuildingHome> get homes => List.unmodifiable(_homes);
  @override
  List<JoinApplication> get applications => List.unmodifiable(_applications);
  @override
  List<ApprovalUpdate> get approvalUpdates =>
      List.unmodifiable(_approvalUpdates);
  @override
  void readApprovalUpdates(List<String> ids) =>
      _approvalUpdates.removeWhere((update) => ids.contains(update.id));
  @override
  List<BoardPost> posts(String buildingId) =>
      List.unmodifiable(_visiblePosts(buildingId).take(kLiveBoardLimit));

  // Every post the resident may see, pinned first, like the server's board.
  List<BoardPost> _visiblePosts(String buildingId) {
    if (!_homes.any((b) => b.id == buildingId)) return const [];
    final result = [
      for (final p in _posts)
        if (p.buildingId == buildingId && !_hiddenPosts.contains(p.id))
          _hiddenReplies.isEmpty
              ? p
              : p.copyWithReplies(
                  p.replies.where((r) => !_hiddenReplies.contains(r.id)),
                ),
    ];
    result.sort(
      (a, b) => a.pinned != b.pinned
          ? (a.pinned ? -1 : 1)
          : b.createdAt.compareTo(a.createdAt),
    );
    return result;
  }

  @override
  BuildingHome createBuilding(
    String name,
    String address,
    String apartment,
    int entrances, {
    String householdName = '',
    String? entrance,
  }) {
    if (address.trim().isEmpty ||
        !RegExp(r'^[0-9]+$').hasMatch(apartment.trim()) ||
        entrances < 1 ||
        entrances > 9 ||
        householdName.trim().length > 60) {
      throw ArgumentError('פרטי בניין לא תקינים');
    }
    final id = _id('home');
    final home = BuildingHome(
      id: id,
      name: name.trim().isEmpty ? address.trim() : name.trim(),
      address: address.trim(),
      apartment: normalizeApartment(apartment),
      entrances: entrances,
      code: 'SH${id.hashCode.abs().toRadixString(36).toUpperCase()}',
      isAdmin: true,
      isCommittee: true,
      isApartmentAdmin: true,
      householdName: householdName.trim(),
      entrance: entrance,
    );
    _homes.add(home);
    return home;
  }

  @override
  void setHousehold(BuildingHome home, String name) {
    final index = _homes.indexWhere((h) => h.id == home.id);
    if (index < 0 || !_homes[index].isApartmentAdmin) {
      throw StateError('אין הרשאה');
    }
    if (name.trim().length > 60) throw StateError('שם הבית ארוך מדי');
    _homes[index] = _homes[index].withHouseholdName(name.trim());
  }

  @override
  BuildingHome? resolveCode(String code) {
    if (code.trim().toUpperCase() == 'NEIGHBOR') {
      return const BuildingHome(
        id: 'new-neighbor',
        name: 'השכנים בשדרה',
        address: 'השדרה 24, תל אביב',
        code: 'NEIGHBOR',
        apartment: '',
        entrances: 2,
      );
    }
    for (final b in _homes) {
      if (b.code == code.trim().toUpperCase()) return b;
    }
    return null;
  }

  bool apartmentHasAdmin(
    BuildingHome home,
    String apartment, [
    String? entrance,
  ]) =>
      home.id == 'new-neighbor' &&
      {'1', '2', '12'}.contains(normalizeApartment(apartment));
  @override
  FutureOr<ApartmentStatus> apartmentStatus(
    BuildingHome home,
    String apartment, {
    String? entrance,
  }) {
    final managed = apartmentHasAdmin(home, apartment, entrance);
    return ApartmentStatus(exists: managed, hasAdmin: managed);
  }

  @override
  JoinApplication apply(
    BuildingHome home,
    String apartment, {
    String? floor,
    String? entrance,
    String householdName = '',
  }) {
    if (!RegExp(r'^[0-9]+$').hasMatch(apartment.trim())) {
      throw ArgumentError('מספר הדירה חייב להכיל ספרות בלבד');
    }
    apartment = normalizeApartment(apartment);
    if (_homes.any((b) => b.id == home.id) ||
        _applications.any((a) => a.building.id == home.id)) {
      throw StateError('כבר קיימת חברות או בקשה לבניין הזה');
    }
    final application = JoinApplication(
      id: _id('application'),
      building: home,
      apartment: normalizeApartment(apartment),
      floor: floor,
      entrance: entrance,
      apartmentHasAdmin: apartmentHasAdmin(home, apartment, entrance),
      requestedHouseholdName: apartmentHasAdmin(home, apartment, entrance)
          ? ''
          : householdName.trim(),
    );
    _applications.add(application);
    return application;
  }

  @override
  void approve(String id, {required bool byBuildingAdmin}) {
    final index = _applications.indexWhere((a) => a.id == id);
    if (index < 0) throw StateError('הבקשה לא נמצאה');
    final previous = _applications[index];
    final updated = previous.copyWith(
      buildingApproved: byBuildingAdmin ? true : null,
      apartmentApproved: byBuildingAdmin ? null : true,
    );
    _applications[index] = updated;
    if (updated.approved && !previous.approved) {
      _approvalUpdates.add(
        ApprovalUpdate(
          id: updated.id,
          buildingId: updated.building.id,
          buildingName: updated.building.name,
        ),
      );
      _homes.add(
        BuildingHome(
          id: updated.building.id,
          name: updated.building.name,
          address: updated.building.address,
          code: updated.building.code,
          apartment: updated.apartment,
          entrances: updated.building.entrances,
          isApartmentAdmin: updated.becomesApartmentAdmin,
          householdName: updated.becomesApartmentAdmin
              ? updated.requestedHouseholdName
              : '',
          entrance: updated.entrance,
        ),
      );
    }
  }

  @override
  void withdraw(String id) =>
      _applications.removeWhere((a) => a.id == id && !a.approved);
  @override
  void publish(BuildingHome home, String text, PostKind kind) {
    if (!_homes.any((b) => b.id == home.id)) {
      throw StateError('נדרש אישור הצטרפות');
    }
    if (text.trim().isEmpty || text.trim().length > 2000) {
      throw ArgumentError('תוכן לא תקין');
    }
    _posts.add(
      BoardPost(
        id: _id('post'),
        buildingId: home.id,
        author: 'אני',
        apartment: home.apartment,
        text: text.trim(),
        kind: kind,
        createdAt: DateTime.now(),
        mine: true,
      ),
    );
  }

  void _update(String id, BoardPost Function(BoardPost) change) {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw StateError('הפרסום לא נמצא');
    _posts[i] = change(_posts[i]);
  }

  @override
  void reply(String id, String text) {
    if (text.trim().isEmpty || text.trim().length > 1000) {
      throw ArgumentError('תגובה לא תקינה');
    }
    _update(id, (p) {
      if (p.closed) throw StateError('הפרסום סגור');
      return p.copyWith(
        replies: List.unmodifiable([
          ...p.replies,
          BoardReply('אני', text.trim(), mine: true, id: _id('reply')),
        ]),
      );
    });
  }

  @override
  void react(String id, String emoji) => _update(id, (p) {
    final mine = {...p.myReactions};
    final counts = {...p.reactions};
    final selected = mine.remove(emoji);
    if (!selected) mine.add(emoji);
    final count = (counts[emoji] ?? 0) + (selected ? -1 : 1);
    count == 0 ? counts.remove(emoji) : counts[emoji] = count;
    return p.copyWith(
      reactions: Map.unmodifiable(counts),
      myReactions: Set.unmodifiable(mine),
    );
  });
  @override
  void edit(String id, String text) => _update(id, (p) {
    if (!p.mine || text.trim().isEmpty || text.trim().length > 2000) {
      throw StateError('לא ניתן לערוך');
    }
    return p.copyWith(text: text.trim());
  });
  @override
  void close(String id) => _update(id, (p) {
    if (!p.mine) throw StateError('רק הכותב יכול לשנות מצב');
    return p.copyWith(closed: !p.closed);
  });
  @override
  void pin(String id, BuildingHome home) => _update(id, (p) {
    if (!home.isAdmin || home.id != p.buildingId) {
      throw StateError('נדרשת הרשאת מנהל');
    }
    return p.copyWith(pinned: !p.pinned);
  });
  @override
  void remove(String id, BuildingHome home) {
    final post = _posts.firstWhere((p) => p.id == id);
    if (post.buildingId != home.id || (!post.mine && !home.isAdmin)) {
      throw StateError('אין הרשאה');
    }
    _posts.remove(post);
  }
}

/// UI state and commands, separate from storage and widgets.
class BuildingViewModel extends ChangeNotifier {
  BuildingViewModel(this.repository, {BoardReadStore? readStore})
    : readStore = readStore ?? MemoryBoardReadStore(),
      _activeId = repository.homes.firstOrNull?.id;
  final BoardReadStore readStore;
  final BuildingRepository repository;
  String? _activeId;
  int _pendingOperations = 0;
  bool _disposed = false;
  bool _synchronizing = false;
  bool get busy => _pendingOperations > 0;
  bool get live => repository.isRemote;
  int tab = 0;
  bool entered = false;
  List<BuildingHome> get homes => repository.homes;
  List<JoinApplication> get pending =>
      repository.applications.where((a) => a.mine && !a.approved).toList();
  List<JoinApplication> get inbox =>
      repository.applications.where((a) => !a.mine && !a.approved).toList();
  List<ApprovalUpdate> get approvalUpdates => repository.approvalUpdates;
  List<BuildingUpdate> get updates => repository.updates;
  StreamSubscription<void>? _changes;
  String? _changesFor;
  Timer? _changeDebounce;

  // Follow the active building's change signal; polling stays as the fallback.
  void _watch() {
    if (_disposed || _changesFor == _activeId) return;
    _changesFor = _activeId;
    unawaited(_changes?.cancel());
    _changes = null;
    final id = _activeId;
    if (id == null) return;
    _changes = repository.changes(id).listen((_) {
      _changeDebounce?.cancel();
      _changeDebounce = Timer(const Duration(milliseconds: 400), () {
        unawaited(synchronize().catchError((Object _) {}));
      });
    }, onError: (Object _) {});
  }

  int get notificationCount =>
      approvalUpdates.length +
      updates.length +
      repository.applications.where((a) => !a.mine && a.needsMyApproval).length;
  bool get needsFastSync => repository.applications.any(
    (a) => !a.approved && (a.mine || a.needsMyApproval),
  );
  BuildingHome? get active => homes.where((b) => b.id == _activeId).firstOrNull;
  // Posts older than the live board, loaded on request, per building.
  final _older = <String, List<BoardPost>>{};
  final _olderHasMore = <String, bool>{};
  bool loadingOlder = false;

  List<BoardPost> get posts {
    final id = active?.id;
    final result = id == null ? <BoardPost>[] : repository.posts(id).toList();
    final older = id == null ? null : _older[id];
    if (older != null && older.isNotEmpty) {
      final live = {for (final p in result) p.id};
      result.addAll(older.where((p) => !live.contains(p.id)));
    }
    result.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime == 0 ? b.id.compareTo(a.id) : byTime;
    });
    return result;
  }

  /// Whether the board may have posts older than those shown. Before the first
  /// request this is known only from a full live board.
  bool get canLoadOlder {
    final id = active?.id;
    if (id == null) return false;
    return _olderHasMore[id] ?? repository.posts(id).length >= kLiveBoardLimit;
  }

  // Where the live board ends: its oldest unpinned post. Pinned posts can be
  // older than the rest of the page.
  DateTime? _liveCursor(String id) {
    final live = repository.posts(id);
    final ordinary = live.where((p) => !p.pinned);
    final from = ordinary.isEmpty ? live : ordinary;
    return from.isEmpty
        ? null
        : from.map((p) => p.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  // Fetches pages from [cursor] until one adds a post not already [known].
  // A page can hold only known posts, e.g. an old pinned post.
  Future<(List<BoardPost>, DateTime?, bool)> _nextOlder(
    String id,
    DateTime? cursor,
    Set<String> known,
  ) async {
    while (true) {
      final page = await repository.boardPage(id, before: cursor);
      final added = page.posts.where((p) => !known.contains(p.id)).toList();
      if (page.posts.isNotEmpty) {
        cursor = page.posts
            .map((p) => p.createdAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      if (added.isNotEmpty || !page.hasMore || page.posts.isEmpty) {
        return (added, cursor, page.hasMore && page.posts.isNotEmpty);
      }
    }
  }

  final _olderCursor = <String, DateTime?>{};

  /// Appends the next page of older posts to the active board.
  Future<void> loadOlder() async {
    final id = active?.id;
    if (id == null || loadingOlder || !canLoadOlder) return;
    loadingOlder = true;
    _notify();
    try {
      final (added, cursor, more) = await _nextOlder(
        id,
        _older[id] == null ? _liveCursor(id) : _olderCursor[id],
        {for (final p in posts) p.id},
      );
      _older[id] = [...?_older[id], ...added];
      _olderCursor[id] = cursor;
      _olderHasMore[id] = more;
    } finally {
      loadingOlder = false;
      _notify();
    }
  }

  // Older posts are a snapshot; after a change, reload as many as were shown
  // so replies, reactions and removals on them appear too.
  Future<void> _reloadOlder() async {
    final id = _activeId;
    final shown = id == null ? null : _older[id];
    if (id == null || shown == null || shown.isEmpty) return;
    final fresh = <BoardPost>[];
    final known = {for (final p in repository.posts(id)) p.id};
    var cursor = _liveCursor(id);
    var more = true;
    while (more && fresh.length < shown.length) {
      final (added, next, hasMore) = await _nextOlder(id, cursor, known);
      fresh.addAll(added);
      known.addAll(added.map((p) => p.id));
      cursor = next;
      more = hasMore && added.isNotEmpty;
    }
    if (_activeId != id) return;
    _older[id] = fresh;
    _olderCursor[id] = cursor;
    _olderHasMore[id] = more;
  }

  /// Background synchronization keeps the current screen usable while waiting.
  Future<void> synchronize() async {
    if (_disposed || busy || _synchronizing) return;
    _synchronizing = true;
    try {
      await repository.refresh(buildingId: _activeId);
      if (!homes.any((h) => h.id == _activeId)) {
        _activeId = homes.firstOrNull?.id;
      }
      await _reloadOlder().catchError((Object _) {});
      _watch();
      _notify();
    } finally {
      _synchronizing = false;
    }
  }

  void enter() {
    entered = true;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (!homes.any((b) => b.id == id)) throw StateError('אין גישה לבניין');
    _activeId = id;
    _notify();
    if (live) await run(() {});
  }

  void navigate(int value) {
    tab = value;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> run(
    FutureOr<void> Function() action, {
    bool refresh = true,
  }) async {
    _pendingOperations++;
    _notify();
    try {
      await action();
      if (refresh) await repository.refresh(buildingId: _activeId);
      if (!homes.any((h) => h.id == _activeId)) {
        _activeId = homes.firstOrNull?.id;
      }
      if (refresh) await _reloadOlder().catchError((Object _) {});
    } finally {
      _pendingOperations--;
      _watch();
      _notify();
    }
  }

  Future<void> initialize() async {
    await run(() {});
    _activeId ??= homes.firstOrNull?.id;
    entered = true;
    _notify();
  }

  Future<void> create(
    String name,
    String address,
    String apartment,
    int entrances, {
    String householdName = '',
    String? entrance,
  }) async {
    await run(() async {
      final home = await repository.createBuilding(
        name,
        address,
        apartment,
        entrances,
        householdName: householdName,
        entrance: entrance,
      );
      _activeId = home.id;
      tab = 0;
    }, refresh: false); // Creation returns the refreshed, authoritative home.
  }

  @override
  void dispose() {
    _disposed = true;
    _changeDebounce?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
