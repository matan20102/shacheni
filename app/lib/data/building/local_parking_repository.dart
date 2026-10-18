import 'parking_repository.dart';

/// In-memory counterpart for previews/tests; never connected to the hosted database.
class ParkingMemoryStore {
  int next = 0;
  final _spaces =
      <String, ({String building, String apartment, ParkingSpace space})>{};
  final _offers = <String, _MemoryOffer>{};
}

class _MemoryOffer {
  _MemoryOffer(this.id, this.spaceId, this.start, this.end);
  final String id, spaceId;
  final DateTime start, end;
  String status = 'available', booker = '', name = '', bookingStatus = '';
}

class LocalParkingRepository implements ParkingRepository {
  LocalParkingRepository({
    required this.apartmentFor,
    this.userId = 'self',
    this.name = 'אני',
    ParkingMemoryStore? store,
  }) : store = store ?? ParkingMemoryStore();
  final String? Function(String buildingId) apartmentFor;
  final String userId, name;
  final ParkingMemoryStore store;
  String _apartment(String b) =>
      apartmentFor(b) ?? (throw StateError('אין גישה לבניין'));
  @override
  Future<ParkingSnapshot> load(String buildingId) async {
    final a = _apartment(buildingId);
    final spaces = store._spaces.values.where((s) => s.building == buildingId);
    final offers = <ParkingOffer>[];
    for (final o in store._offers.values) {
      final s = store._spaces[o.spaceId]!;
      if (s.building != buildingId || !o.end.isAfter(DateTime.now())) continue;
      final own = s.apartment == a, mine = o.booker == userId;
      if (!own && !mine && o.status != 'available') continue;
      offers.add(
        ParkingOffer(
          id: o.id,
          space: s.space,
          apartment: s.apartment,
          startsAt: o.start,
          endsAt: o.end,
          status: o.status,
          ownSpace: own,
          myBooking: mine,
          bookingStatus: own || mine ? o.bookingStatus : '',
          bookerName: own || mine ? o.name : '',
          canBook: !own && o.status == 'available',
          canCancel:
              o.status != 'cancelled' &&
              (own || (mine && o.bookingStatus == 'confirmed')),
        ),
      );
    }
    offers.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return ParkingSnapshot(
      spaces: List.unmodifiable(
        spaces.where((s) => s.apartment == a).map((s) => s.space),
      ),
      offers: List.unmodifiable(offers),
    );
  }

  @override
  Future<void> addSpace(
    String buildingId,
    String label,
    String level,
    String notes,
  ) async {
    final apartment = _apartment(buildingId);
    if (label.trim().isEmpty ||
        label.trim().length > 20 ||
        level.length > 20 ||
        notes.length > 200) {
      throw StateError('יש לבדוק את פרטי החניה');
    }
    if (store._spaces.values.any(
      (s) =>
          s.building == buildingId &&
          s.space.label.toLowerCase() == label.trim().toLowerCase(),
    )) {
      throw StateError('PARKING_LABEL_TAKEN');
    }
    final id = 'space-${++store.next}';
    store._spaces[id] = (
      building: buildingId,
      apartment: apartment,
      space: ParkingSpace(
        id: id,
        label: label.trim(),
        level: level.trim(),
        notes: notes.trim(),
      ),
    );
  }

  @override
  Future<void> publish(String spaceId, DateTime start, DateTime end) async {
    final s = store._spaces[spaceId]!;
    if (_apartment(s.building) != s.apartment) throw StateError('אין הרשאה');
    final now = DateTime.now();
    if (start.isBefore(now.subtract(const Duration(minutes: 5))) ||
        start.isAfter(now.add(const Duration(days: 90))) ||
        !end.isAfter(start) ||
        !end.isAfter(now) ||
        end.difference(start) > const Duration(days: 90)) {
      throw StateError('INVALID_TIME_RANGE');
    }
    if (store._offers.values.any(
      (o) =>
          o.spaceId == spaceId &&
          o.status != 'cancelled' &&
          start.isBefore(o.end) &&
          end.isAfter(o.start),
    )) {
      throw StateError('PARKING_OVERLAP');
    }
    final id = 'offer-${++store.next}';
    store._offers[id] = _MemoryOffer(id, spaceId, start, end);
  }

  @override
  Future<void> book(String offerId) async {
    final o = store._offers[offerId]!;
    final s = store._spaces[o.spaceId]!;
    if (_apartment(s.building) == s.apartment) throw StateError('OWN_PARKING');
    if (!o.end.isAfter(DateTime.now())) throw StateError('PARKING_EXPIRED');
    if (o.status == 'booked' && o.booker == userId) return;
    if (o.status != 'available') throw StateError('PARKING_UNAVAILABLE');
    o.status = 'booked';
    o.booker = userId;
    o.name = name;
    o.bookingStatus = 'confirmed';
  }

  @override
  Future<void> cancel(String offerId) async {
    final o = store._offers[offerId]!;
    final s = store._spaces[o.spaceId]!;
    final own = _apartment(s.building) == s.apartment;
    if (!own && (o.booker != userId || o.bookingStatus != 'confirmed')) {
      throw StateError('אין הרשאה');
    }
    if (!o.end.isAfter(DateTime.now())) throw StateError('PARKING_EXPIRED');
    o.status = own ? 'cancelled' : 'available';
    if (o.booker.isNotEmpty) o.bookingStatus = 'cancelled';
  }
}
