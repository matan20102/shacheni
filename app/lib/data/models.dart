/// Prototype domain models. They mirror the PRD state machines (§11) and are used by the
/// in-memory [DemoData] store. When the Supabase backend is wired in (Phase 8+), these
/// become the entities behind repository interfaces; screens do not change.
library;

enum AuthStage { welcome, phone, otp, legal, join, apply, pending, approved }

enum ListingStatus { available, reserved, active, completed, cancelled, expired }

enum ReservationStatus {
  requested,
  accepted,
  confirmed,
  active,
  completed,
  cancelled,
  declined,
  expired,
}

enum RequestStatus {
  open,
  offerReceived,
  accepted,
  collected,
  delivered,
  completed,
  cancelled,
  expired,
  disputed,
}

enum OfferStatus { pending, accepted, rejected, withdrawn, expired }

/// MVP mock payment lifecycle (PRD §11.8) — no funds are ever held.
enum PaymentStatus { pending, payerConfirmed, settled, cancelled }

enum TxType { parking, delivery }

enum TxStatus { inProgress, awaitingSettlement, completed, cancelled, disputed }

enum AssignmentStatus { requested, active, rejected, ended }

enum ApplicationStatus { pending, infoRequested, approved, rejected }

enum HandoffMethod { code, doorPhoto }

enum CodeResult { ok, wrong, locked }

/// Bilingual user-facing *data* (names, places, descriptions). Real user content is
/// stored once in the database; the prototype keeps both variants so a language switch
/// looks natural in the demo.
class Bi {
  const Bi(this.he, [String? en]) : en = en ?? he;
  final String he;
  final String en;
  String of(String lang) => lang == 'he' ? he : en;
  bool get isEmpty => he.isEmpty && en.isEmpty;
}

class Person {
  Person({
    required this.id,
    required this.firstHe,
    required this.firstEn,
    required this.lastHe,
    required this.lastEn,
    required this.colorIndex,
    this.rating,
    this.ratingCount = 0,
    this.completed = 0,
    this.apartment = '',
    this.phone = '',
    this.memberSince = 2026,
  });

  final String id;
  final String firstHe, firstEn, lastHe, lastEn;
  final int colorIndex;
  double? rating;
  int ratingCount;
  int completed;
  final String apartment;
  final String phone;
  final int memberSince;

  String first(String lang) => lang == 'he' ? firstHe : firstEn;

  /// Public display name: first name + last initial (BR-K1).
  String shortName(String lang) => lang == 'he' ? '$firstHe $lastHe׳' : '$firstEn $lastEn.';

  String initial(String lang) => first(lang).substring(0, 1);

  bool get isNew => ratingCount < 3;
}

class ParkingListing {
  ParkingListing({
    required this.id,
    required this.spaceLabel,
    required this.ownerId,
    required this.start,
    required this.end,
    required this.priceMinor,
    this.description = const Bi(''),
    this.instant = false,
    this.status = ListingStatus.available,
  });

  final String id;
  final String spaceLabel;
  final String ownerId;
  final DateTime start;
  final DateTime end;
  final int priceMinor;
  final Bi description;
  bool instant;
  ListingStatus status;
}

class Reservation {
  Reservation({
    required this.id,
    required this.listingId,
    required this.spaceLabel,
    required this.requesterId,
    required this.ownerId,
    required this.start,
    required this.end,
    required this.priceMinor,
    required this.createdAt,
    this.status = ReservationStatus.requested,
    this.plate = '',
    this.note = '',
    this.txId,
    this.expiresAt,
  });

  final String id;
  final String listingId;
  final String spaceLabel;
  final String requesterId;
  final String ownerId;
  final DateTime start;
  final DateTime end;
  final int priceMinor;
  final DateTime createdAt;
  ReservationStatus status;
  String plate;
  String note;
  String? txId;
  DateTime? expiresAt;
}

class Offer {
  Offer({
    required this.id,
    required this.helperId,
    this.message = const Bi(''),
    this.plannedAt,
    this.status = OfferStatus.pending,
  });

  final String id;
  final String helperId;
  final Bi message;
  final DateTime? plannedAt;
  OfferStatus status;
}

class DeliveryRequest {
  DeliveryRequest({
    required this.id,
    required this.requesterId,
    required this.location,
    required this.description,
    required this.deadline,
    required this.rewardMinor,
    required this.createdAt,
    this.notes = const Bi(''),
    this.handoffPlace = const Bi(''),
    this.doorAllowed = false,
    this.status = RequestStatus.open,
    this.pickupRef = '',
    List<Offer>? offers,
  }) : offers = offers ?? [];

  final String id;
  final String requesterId;
  final Bi location;
  final Bi description;
  final Bi notes;
  final Bi handoffPlace;
  final DateTime deadline;
  final int rewardMinor;
  final DateTime createdAt;
  final String pickupRef;
  bool doorAllowed; // door_delivery_allowed / door_delivery_approved_at (merged in the demo)
  RequestStatus status;
  final List<Offer> offers;

  // Set once an offer is accepted.
  String? helperId;
  String? txId;
  String code = '';
  int failedAttempts = 0;
  DateTime? lockedUntil;
  int regenCount = 0;

  // Handoff progress.
  DateTime? collectedAt;
  DateTime? arrivedAt;
  DateTime? deliveredAt;
  HandoffMethod? handoffMethod;
  String? proofNote;
  DateTime? proofAt;
  DateTime? autoConfirmAt;
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.refId,
    required this.title,
    required this.payerId,
    required this.payeeId,
    required this.amountMinor,
    required this.createdAt,
    this.status = TxStatus.inProgress,
    this.pay = PaymentStatus.pending,
    this.windowStart,
    this.windowEnd,
  });

  final String id;
  final TxType type;
  final String refId;

  /// Space label for parking, pickup location for delivery.
  final Bi title;
  final String payerId;
  final String payeeId;
  final int amountMinor;
  final DateTime createdAt;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  TxStatus status;
  PaymentStatus pay;
  DateTime? serviceDoneAt;
  DateTime? completedAt;
  DateTime? settledAt;
  int notReceivedCount = 0;
  bool ratedByMe = false;
  bool refundRecord = false;
}

class Assignment {
  Assignment({required this.id, required this.spaceLabel, required this.status});
  final String id;
  final String spaceLabel;
  AssignmentStatus status;
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.time,
    this.params = const {},
    this.route,
    this.read = false,
  });

  final String id;

  /// Catalog code, e.g. `parking.request_received` (PRD §13). Rendered from ARB.
  final String type;
  final Map<String, String> params;
  final String? route;
  final DateTime time;
  bool read;
}

class ApplicationItem {
  ApplicationItem({
    required this.id,
    required this.name,
    required this.apartment,
    required this.phone,
    required this.submittedAt,
    this.spaces = const [],
    this.status = ApplicationStatus.pending,
    this.secondResident = false,
    this.spaceHeldByOther = false,
    this.isMine = false,
  });

  final String id;
  final Bi name;
  final String apartment;
  final String phone;
  final DateTime submittedAt;
  final List<String> spaces;
  ApplicationStatus status;
  final bool secondResident;
  final bool spaceHeldByOther;
  final bool isMine;
}

class AssignmentRequestItem {
  AssignmentRequestItem({
    required this.id,
    required this.residentName,
    required this.apartment,
    required this.spaceLabel,
    this.heldByOther = false,
    this.isMine = false,
    this.status = AssignmentStatus.requested,
  });
  final String id;
  final Bi residentName;
  final String apartment;
  final String spaceLabel;
  final bool heldByOther;
  final bool isMine;
  AssignmentStatus status;
}

class Dispute {
  Dispute({
    required this.id,
    required this.txId,
    required this.reasonKey,
    required this.description,
    required this.createdAt,
    this.resolved = false,
  });
  final String id;
  final String txId;
  final String reasonKey;
  final String description;
  final DateTime createdAt;
  bool resolved;
}
