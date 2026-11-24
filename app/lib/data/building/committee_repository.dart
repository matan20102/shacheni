import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_error.dart';
import 'inquiry_repository.dart';

/// How the committee is paid: links it pasted once, and a note for cash.
@immutable
class CommitteeSettings {
  const CommitteeSettings({
    this.monthlyAmount = 0,
    this.monthlyDueDay = 10,
    this.bitLink = '',
    this.payboxLink = '',
    this.cashNote = '',
  });
  final int monthlyAmount, monthlyDueDay;
  final String bitLink, payboxLink, cashNote;
  bool get canPayInApp => bitLink.isNotEmpty || payboxLink.isNotEmpty;
  factory CommitteeSettings.fromJson(Map<String, dynamic> j) =>
      CommitteeSettings(
        monthlyAmount: (j['monthly_amount'] as num?)?.toInt() ?? 0,
        monthlyDueDay: (j['monthly_due_day'] as num?)?.toInt() ?? 10,
        bitLink: j['bit_link'] as String? ?? '',
        payboxLink: j['paybox_link'] as String? ?? '',
        cashNote: j['cash_note'] as String? ?? '',
      );
}

/// One apartment's state for a charge, as the committee sees it.
@immutable
class CommitteeApartment {
  const CommitteeApartment({
    required this.apartmentId,
    required this.apartment,
    this.status = '',
    this.method = '',
  });
  final String apartmentId, apartment;

  /// '' (not paid), 'reported' (the resident says paid) or 'confirmed'.
  final String status, method;
  factory CommitteeApartment.fromJson(Map<String, dynamic> j) =>
      CommitteeApartment(
        apartmentId: j['apartment_id'] as String,
        apartment: j['apartment'] as String,
        status: j['status'] as String? ?? '',
        method: j['method'] as String? ?? '',
      );
}

@immutable
class CommitteeCharge {
  const CommitteeCharge({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueOn,
    this.monthly = false,
    this.period,
    this.notes = '',
    this.myStatus = '',
    this.paid = 0,
    this.households = 0,
    this.apartments = const [],
  });
  final String id, title, notes;
  final int amount, paid, households;
  final DateTime dueOn;
  final bool monthly;

  /// The month a monthly fee belongs to.
  final DateTime? period;

  /// This apartment: '' (to pay), 'reported' or 'confirmed'.
  final String myStatus;
  final List<CommitteeApartment> apartments;
  bool get settled => myStatus == 'confirmed';
  factory CommitteeCharge.fromJson(Map<String, dynamic> j) => CommitteeCharge(
    id: j['id'] as String,
    title: j['title'] as String,
    notes: j['notes'] as String? ?? '',
    amount: (j['amount'] as num).toInt(),
    dueOn: DateTime.parse(j['due_on'] as String),
    monthly: j['kind'] == 'monthly',
    period: j['period'] == null ? null : DateTime.parse(j['period'] as String),
    myStatus: j['my_status'] as String? ?? '',
    paid: (j['paid'] as num?)?.toInt() ?? 0,
    households: (j['households'] as num?)?.toInt() ?? 0,
    apartments: List.unmodifiable([
      for (final a in j['apartments'] as List? ?? const [])
        CommitteeApartment.fromJson(a as Map<String, dynamic>),
    ]),
  );
}

/// A resident the committee can add or remove.
@immutable
class CommitteeMember {
  const CommitteeMember({
    required this.id,
    required this.name,
    required this.apartment,
    this.isAdmin = false,
    this.onCommittee = false,
  });
  final String id, name, apartment;
  final bool isAdmin, onCommittee;
  factory CommitteeMember.fromJson(Map<String, dynamic> j) => CommitteeMember(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    apartment: j['apartment'] as String? ?? '',
    isAdmin: j['is_admin'] == true,
    onCommittee: j['is_committee'] == true,
  );
}

@immutable
class CommitteeSnapshot {
  const CommitteeSnapshot({
    this.isCommittee = false,
    this.committee = const [],
    this.members = const [],
    this.settings = const CommitteeSettings(),
    this.charges = const [],
  });
  final bool isCommittee;

  /// Names of the committee, shown to every resident.
  final List<String> committee;
  final List<CommitteeMember> members;
  final CommitteeSettings settings;
  final List<CommitteeCharge> charges;
  factory CommitteeSnapshot.fromJson(Map<String, dynamic> j) =>
      CommitteeSnapshot(
        isCommittee: j['is_committee'] == true,
        committee: List.unmodifiable([
          for (final n in j['committee'] as List? ?? const []) n as String,
        ]),
        members: List.unmodifiable([
          for (final m in j['members'] as List? ?? const [])
            CommitteeMember.fromJson(m as Map<String, dynamic>),
        ]),
        settings: CommitteeSettings.fromJson(
          j['settings'] as Map<String, dynamic>? ?? const {},
        ),
        charges: List.unmodifiable([
          for (final c in j['charges'] as List? ?? const [])
            CommitteeCharge.fromJson(c as Map<String, dynamic>),
        ]),
      );
}

abstract interface class CommitteeRepository {
  Future<CommitteeSnapshot> load(String buildingId);
  Future<void> saveSettings(String buildingId, CommitteeSettings settings);
  Future<void> addCharge(
    String buildingId, {
    required String title,
    required String notes,
    required int amount,
    required DateTime dueOn,
  });
  Future<void> cancelCharge(String chargeId);

  /// The resident says their apartment paid, with 'bit', 'paybox' or 'cash'.
  Future<void> reportPaid(String chargeId, String method);

  /// The committee marks an apartment paid or not paid.
  Future<void> markPaid(
    String chargeId,
    String apartmentId,
    bool paid, {
    String? method,
  });
  Future<void> setMember(String memberId, bool onCommittee);

  /// Private messages between residents and the committee.
  InquiryRepository get inquiries;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SupabaseCommitteeRepository implements CommitteeRepository {
  SupabaseCommitteeRepository(this.client);
  final SupabaseClient client;
  @override
  late final InquiryRepository inquiries = SupabaseInquiryRepository(client);
  @override
  Future<CommitteeSnapshot> load(String buildingId) async =>
      CommitteeSnapshot.fromJson(
        await client.rpc('ba_committee', params: {'p_building': buildingId})
            as Map<String, dynamic>,
      );
  @override
  Future<void> saveSettings(String buildingId, CommitteeSettings s) async {
    await client.rpc(
      'ba_committee_settings',
      params: {
        'p_building': buildingId,
        'p_monthly_amount': s.monthlyAmount,
        'p_monthly_due_day': s.monthlyDueDay,
        'p_bit_link': s.bitLink,
        'p_paybox_link': s.payboxLink,
        'p_cash_note': s.cashNote,
      },
    );
  }

  @override
  Future<void> addCharge(
    String buildingId, {
    required String title,
    required String notes,
    required int amount,
    required DateTime dueOn,
  }) async {
    await client.rpc(
      'ba_committee_charge',
      params: {
        'p_building': buildingId,
        'p_title': title,
        'p_notes': notes,
        'p_amount': amount,
        'p_due': _date(dueOn),
      },
    );
  }

  @override
  Future<void> cancelCharge(String chargeId) async {
    await client.rpc('ba_committee_cancel', params: {'p_charge': chargeId});
  }

  @override
  Future<void> reportPaid(String chargeId, String method) async {
    await client.rpc(
      'ba_committee_report',
      params: {'p_charge': chargeId, 'p_method': method},
    );
  }

  @override
  Future<void> markPaid(
    String chargeId,
    String apartmentId,
    bool paid, {
    String? method,
  }) async {
    await client.rpc(
      'ba_committee_mark',
      params: {
        'p_charge': chargeId,
        'p_apartment': apartmentId,
        'p_paid': paid,
        'p_method': method,
      },
    );
  }

  @override
  Future<void> setMember(String memberId, bool onCommittee) async {
    await client.rpc(
      'ba_committee_set_member',
      params: {'p_member': memberId, 'p_on': onCommittee},
    );
  }
}

/// In-memory committee for previews and tests; never touches the server.
class LocalCommitteeRepository implements CommitteeRepository {
  LocalCommitteeRepository({
    required this.apartmentFor,
    required this.isAdminFor,
    this.name = 'אני',
  });
  final String? Function(String buildingId) apartmentFor;
  final bool Function(String buildingId) isAdminFor;
  final String name;
  final _settings = <String, CommitteeSettings>{};
  final _charges = <String, List<_LocalCharge>>{};
  final _extraCommittee = <String, Set<String>>{};
  int _next = 0;
  @override
  late final LocalInquiryRepository inquiries = LocalInquiryRepository(
    apartmentFor: apartmentFor,
    isCommitteeFor: _boss,
    name: name,
  );

  String _apartment(String b) =>
      apartmentFor(b) ?? (throw StateError('אין גישה לבניין'));
  bool _boss(String b) =>
      isAdminFor(b) || (_extraCommittee[b]?.contains('self') ?? false);
  List<({String id, String name, String apartment})> _people(String b) => [
    (id: 'self', name: name, apartment: _apartment(b)),
    (id: 'neighbor-2', name: 'דנה לוי', apartment: '2'),
    (id: 'neighbor-20', name: 'יואב כהן', apartment: '20'),
  ];
  String _chargeBuilding(String chargeId) => _charges.entries
      .firstWhere((e) => e.value.any((c) => c.id == chargeId))
      .key;
  _LocalCharge _charge(String id) =>
      _charges.values.expand((c) => c).firstWhere((c) => c.id == id);

  /// The building last opened; members are picked from its list.
  String? _current;

  @override
  Future<CommitteeSnapshot> load(String b) async {
    final mine = _apartment(b);
    _current = b;
    final boss = _boss(b);
    final s = _settings[b] ?? const CommitteeSettings();
    final list = _charges.putIfAbsent(b, () => []);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    if (s.monthlyAmount > 0 &&
        !list.any((c) => c.monthly && c.period == month)) {
      list.add(
        _LocalCharge(
          'charge-${++_next}',
          'דמי ועד',
          '',
          s.monthlyAmount,
          _monthlyDue(s.monthlyDueDay),
          period: month,
        ),
      );
    }
    final apartments = {for (final p in _people(b)) p.apartment}.toList()
      ..sort();
    final committee = [
      for (final p in _people(b))
        if ((p.id == 'self' && boss) ||
            (_extraCommittee[b]?.contains(p.id) ?? false))
          p.name,
    ];
    final charges = [
      for (final c in list.where((c) => !c.cancelled))
        CommitteeCharge(
          id: c.id,
          title: c.title,
          notes: c.notes,
          amount: c.amount,
          dueOn: c.due,
          monthly: c.monthly,
          period: c.period,
          myStatus: c.status[mine]?.status ?? '',
          paid: c.status.values.where((p) => p.status == 'confirmed').length,
          households: apartments.length,
          apartments: boss
              ? [
                  for (final a in apartments)
                    CommitteeApartment(
                      apartmentId: 'apt-$a',
                      apartment: a,
                      status: c.status[a]?.status ?? '',
                      method: c.status[a]?.method ?? '',
                    ),
                ]
              : const [],
        ),
    ]..sort((x, y) => y.dueOn.compareTo(x.dueOn));
    return CommitteeSnapshot(
      isCommittee: boss,
      committee: committee,
      members: boss
          ? [
              for (final p in _people(b))
                CommitteeMember(
                  id: p.id,
                  name: p.name,
                  apartment: p.apartment,
                  isAdmin: p.id == 'self' && isAdminFor(b),
                  onCommittee:
                      (p.id == 'self' && boss) ||
                      (_extraCommittee[b]?.contains(p.id) ?? false),
                ),
            ]
          : const [],
      settings: s,
      charges: List.unmodifiable(charges),
    );
  }

  void _requireBoss(String b) {
    _apartment(b);
    if (!_boss(b)) throw StateError('ACCESS_DENIED');
  }

  static bool _linkOk(String l) =>
      l.isEmpty || (l.startsWith('https://') && !l.contains(' '));

  @override
  Future<void> saveSettings(String b, CommitteeSettings s) async {
    _requireBoss(b);
    if (s.monthlyAmount < 0 ||
        s.monthlyAmount > 100000 ||
        s.monthlyDueDay < 1 ||
        s.monthlyDueDay > 28 ||
        !_linkOk(s.bitLink) ||
        !_linkOk(s.payboxLink)) {
      throw StateError('INVALID_ARGUMENT');
    }
    _settings[b] = s;
    final now = DateTime.now();
    for (final c in _charges[b] ?? <_LocalCharge>[]) {
      if (c.monthly &&
          c.period == DateTime(now.year, now.month) &&
          c.status.isEmpty &&
          s.monthlyAmount > 0) {
        c.amount = s.monthlyAmount;
        c.due = _monthlyDue(s.monthlyDueDay);
      }
    }
  }

  @override
  Future<void> addCharge(
    String b, {
    required String title,
    required String notes,
    required int amount,
    required DateTime dueOn,
  }) async {
    _requireBoss(b);
    final today = _day(DateTime.now());
    if (title.trim().isEmpty ||
        title.trim().length > 80 ||
        notes.length > 500 ||
        amount < 1 ||
        amount > 100000 ||
        dueOn.isBefore(today)) {
      throw StateError('INVALID_ARGUMENT');
    }
    _charges
        .putIfAbsent(b, () => [])
        .add(
          _LocalCharge(
            'charge-${++_next}',
            title.trim(),
            notes.trim(),
            amount,
            _day(dueOn),
          ),
        );
  }

  @override
  Future<void> cancelCharge(String chargeId) async {
    _requireBoss(_chargeBuilding(chargeId));
    _charge(chargeId).cancelled = true;
  }

  @override
  Future<void> reportPaid(String chargeId, String method) async {
    final c = _charge(chargeId);
    final mine = _apartment(_chargeBuilding(chargeId));
    if (c.cancelled) throw StateError('COMMITTEE_CHARGE_CLOSED');
    if (c.status[mine]?.status == 'confirmed') return;
    c.status[mine] = (status: 'reported', method: method);
  }

  @override
  Future<void> markPaid(
    String chargeId,
    String apartmentId,
    bool paid, {
    String? method,
  }) async {
    _requireBoss(_chargeBuilding(chargeId));
    final c = _charge(chargeId);
    if (c.cancelled) throw StateError('COMMITTEE_CHARGE_CLOSED');
    final a = apartmentId.replaceFirst('apt-', '');
    if (paid) {
      c.status[a] = (
        status: 'confirmed',
        method: method ?? c.status[a]?.method ?? 'cash',
      );
    } else {
      c.status.remove(a);
    }
  }

  @override
  Future<void> setMember(String memberId, bool onCommittee) async {
    final b = _current;
    if (b == null) throw StateError('ACCESS_DENIED');
    _requireBoss(b);
    if (memberId == 'self' && isAdminFor(b) && !onCommittee) {
      throw StateError('COMMITTEE_ADMIN');
    }
    final set = _extraCommittee.putIfAbsent(b, () => {});
    onCommittee ? set.add(memberId) : set.remove(memberId);
  }
}

/// This month's due day, or a week from today when that day has passed.
DateTime _monthlyDue(int day) {
  final now = DateTime.now();
  final due = DateTime(now.year, now.month, day);
  final week = _day(now).add(const Duration(days: 7));
  return due.isBefore(week) ? week : due;
}

class _LocalCharge {
  _LocalCharge(
    this.id,
    this.title,
    this.notes,
    this.amount,
    this.due, {
    this.period,
  });
  final String id, title, notes;
  int amount;
  DateTime due;
  final DateTime? period;
  bool get monthly => period != null;
  bool cancelled = false;
  final status = <String, ({String status, String method})>{};
}

String committeeError(Object error) {
  final message = error is PostgrestException
      ? error.message
      : error.toString();
  for (final entry in const {
    'COMMITTEE_ADMIN': 'מנהלי הבניין תמיד חברים בוועד.',
    'COMMITTEE_CHARGE_CLOSED': 'החיוב הזה בוטל בינתיים. הרשימה מתעדכנת.',
    'INVALID_ARGUMENT': 'יש לבדוק את הפרטים שהזנת.',
  }.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  return buildingErrorMessage(error);
}

class CommitteeViewModel extends ChangeNotifier {
  CommitteeViewModel(this.repository, this.buildingId);
  final CommitteeRepository repository;
  final String buildingId;
  CommitteeSnapshot snapshot = const CommitteeSnapshot();
  bool loading = false, saving = false, loaded = false, _disposed = false;
  String? error;
  int _generation = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    _notify();
    try {
      final next = await repository.load(buildingId);
      if (_disposed || generation != _generation) return;
      snapshot = next;
      error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = committeeError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        loaded = true;
        _notify();
      }
    }
  }

  Future<bool> run(Future<void> Function() action) async {
    if (saving || _disposed) return false;
    saving = true;
    error = null;
    ++_generation;
    _notify();
    try {
      await action();
    } catch (e) {
      final message = committeeError(e);
      await load();
      if (!_disposed) error = message;
      return false;
    } finally {
      if (!_disposed) {
        saving = false;
        _notify();
      }
    }
    if (!_disposed) await load();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
