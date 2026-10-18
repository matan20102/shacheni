import 'dart:async';

import 'package:flutter/foundation.dart';

import 'board_read_store.dart';

enum PostKind { notice, request }

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
  });
  final String id, name, address, code, apartment;
  final String householdName;
  final String? entrance;
  final int entrances;
  final bool isAdmin, isCommittee;
  final bool isApartmentAdmin;

  BuildingHome withHouseholdName(String value) => BuildingHome(
    id: id,
    name: name,
    address: address,
    code: code,
    apartment: apartment,
    entrances: entrances,
    isAdmin: isAdmin,
    isCommittee: isCommittee,
    isApartmentAdmin: isApartmentAdmin,
    householdName: value,
    entrance: entrance,
  );
}

@immutable
class BoardReply {
  const BoardReply(this.author, this.text);
  final String author, text;
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
    this.replies = const [],
    this.reactions = const {},
    this.myReactions = const {},
  });
  final String id, buildingId, author, apartment, text;
  final PostKind kind;
  final DateTime createdAt;
  final bool mine, pinned, closed;
  final List<BoardReply> replies;
  final Map<String, int> reactions;
  final Set<String> myReactions;

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
}

/// Repository boundary for the new product. This first adapter deliberately
/// keeps all writes in memory; it never uses or mutates the shared Supabase DB.
class LocalBuildingRepository implements BuildingRepository {
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
    if (home.isAdmin) {
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
  List<BoardPost> posts(String buildingId) {
    if (!_homes.any((b) => b.id == buildingId)) return const [];
    final result = _posts.where((p) => p.buildingId == buildingId).toList();
    result.sort(
      (a, b) => a.pinned != b.pinned
          ? (a.pinned ? -1 : 1)
          : b.createdAt.compareTo(a.createdAt),
    );
    return List.unmodifiable(result);
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
          BoardReply('אני', text.trim()),
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
  int get notificationCount =>
      approvalUpdates.length +
      inbox
          .where(
            (a) =>
                (!a.buildingApproved && a.canApproveBuilding) ||
                (a.apartmentHasAdmin &&
                    !a.apartmentApproved &&
                    a.canApproveApartment),
          )
          .length;
  BuildingHome? get active => homes.where((b) => b.id == _activeId).firstOrNull;
  List<BoardPost> get posts {
    final result = active == null
        ? <BoardPost>[]
        : repository.posts(active!.id).toList();
    result.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime == 0 ? b.id.compareTo(a.id) : byTime;
    });
    return result;
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
    } finally {
      _pendingOperations--;
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
    super.dispose();
  }
}
