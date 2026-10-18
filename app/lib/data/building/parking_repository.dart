import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_error.dart';

@immutable
class ParkingSpace {
  const ParkingSpace({
    required this.id,
    required this.label,
    this.level = '',
    this.notes = '',
  });
  final String id, label, level, notes;
  factory ParkingSpace.fromJson(Map<String, dynamic> j) => ParkingSpace(
    id: j['id'] as String,
    label: j['label'] as String,
    level: j['level'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );
}

@immutable
class ParkingOffer {
  const ParkingOffer({
    required this.id,
    required this.space,
    required this.apartment,
    required this.startsAt,
    required this.endsAt,
    this.status = 'available',
    this.ownSpace = false,
    this.myBooking = false,
    this.bookingStatus = '',
    this.bookerName = '',
    this.canBook = false,
    this.canCancel = false,
  });
  final String id, apartment, status, bookingStatus, bookerName;
  final ParkingSpace space;
  final DateTime startsAt, endsAt;
  final bool ownSpace, myBooking, canBook, canCancel;
  factory ParkingOffer.fromJson(Map<String, dynamic> j) => ParkingOffer(
    id: j['id'] as String,
    space: ParkingSpace.fromJson({...j, 'id': j['space_id']}),
    apartment: j['apartment'] as String,
    startsAt: DateTime.parse(j['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(j['ends_at'] as String).toLocal(),
    status: j['status'] as String,
    ownSpace: j['own_space'] == true,
    myBooking: j['my_booking'] == true,
    bookingStatus: j['booking_status'] as String? ?? '',
    bookerName: j['booker_name'] as String? ?? '',
    canBook: j['can_book'] == true,
    canCancel: j['can_cancel'] == true,
  );
}

@immutable
class ParkingSnapshot {
  const ParkingSnapshot({this.spaces = const [], this.offers = const []});
  final List<ParkingSpace> spaces;
  final List<ParkingOffer> offers;
  factory ParkingSnapshot.fromJson(Map<String, dynamic> j) => ParkingSnapshot(
    spaces: List.unmodifiable([
      for (final s in j['spaces'] as List)
        ParkingSpace.fromJson(s as Map<String, dynamic>),
    ]),
    offers: List.unmodifiable([
      for (final o in j['offers'] as List)
        ParkingOffer.fromJson(o as Map<String, dynamic>),
    ]),
  );
}

abstract interface class ParkingRepository {
  Future<ParkingSnapshot> load(String buildingId);
  Future<void> addSpace(
    String buildingId,
    String label,
    String level,
    String notes,
  );
  Future<void> publish(String spaceId, DateTime start, DateTime end);
  Future<void> book(String offerId);
  Future<void> cancel(String offerId);
}

class SupabaseParkingRepository implements ParkingRepository {
  SupabaseParkingRepository(this.client);
  final SupabaseClient client;
  @override
  Future<ParkingSnapshot> load(String buildingId) async =>
      ParkingSnapshot.fromJson(
        await client.rpc('ba_parking', params: {'p_building': buildingId})
            as Map<String, dynamic>,
      );
  @override
  Future<void> addSpace(
    String buildingId,
    String label,
    String level,
    String notes,
  ) async {
    await client.rpc(
      'ba_parking_add',
      params: {
        'p_building': buildingId,
        'p_label': label,
        'p_level': level,
        'p_notes': notes,
      },
    );
  }

  @override
  Future<void> publish(String spaceId, DateTime start, DateTime end) async {
    await client.rpc(
      'ba_parking_publish',
      params: {
        'p_space': spaceId,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> book(String offerId) async {
    await client.rpc('ba_parking_book', params: {'p_offer': offerId});
  }

  @override
  Future<void> cancel(String offerId) async {
    await client.rpc('ba_parking_cancel', params: {'p_offer': offerId});
  }
}

String parkingError(Object error) {
  final message = error is PostgrestException
      ? error.message
      : error.toString();
  for (final entry in const {
    'PARKING_LABEL_TAKEN': 'סימון החניה כבר רשום בבניין. כדאי לבדוק שהסימון נכון.',
    'PARKING_OVERLAP': 'כבר פורסמה זמינות לחניה הזאת בשעות שנבחרו.',
    'INVALID_TIME_RANGE': 'יש לבחור טווח עתידי תקין של עד 90 יום.',
    'PARKING_UNAVAILABLE':
        'החניה כבר אינה פנויה. הרשימה תתעדכן ואפשר לבחור חניה אחרת.',
    'PARKING_EXPIRED': 'טווח החניה הזה כבר הסתיים.',
    'OWN_PARKING': 'זו חניה של הדירה שלך; אין צורך להזמין אותה.',
  }.entries) {
    if (message.contains(entry.key)) return entry.value;
  }
  return buildingErrorMessage(error);
}

class ParkingViewModel extends ChangeNotifier {
  ParkingViewModel(this.repository, this.buildingId);
  final ParkingRepository repository;
  final String buildingId;
  ParkingSnapshot snapshot = const ParkingSnapshot();
  bool loading = false, saving = false, _disposed = false;
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
      snapshot = const ParkingSnapshot();
      error = parkingError(e);
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
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
      final message = parkingError(e);
      // A lost race should refresh availability while retaining its explanation.
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
