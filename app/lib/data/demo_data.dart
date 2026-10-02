import 'dart:math';

import 'models.dart';

/// In-memory prototype of the server side. Method names and guards follow the RPC list in
/// the architecture doc (e.g. `confirmHandoff` ≙ `confirm_handoff`). It exists only so the
/// UI can be reviewed end to end before the Supabase backend (Phase 5/8) is wired in.
class DemoData {
  DemoData({AuthStage? startStage}) {
    if (startStage != null) stage = startStage;
    _seed();
  }

  static const meId = 'me';
  static const joinCode = 'SHACH-26';

  final DateTime t0 = DateTime.now();
  final _rng = Random(7);
  int _seq = 100;

  // ---- session / access -------------------------------------------------------------
  AuthStage stage = AuthStage.welcome;
  String phone = '';
  bool isAdmin = true; // pilot: the owner is platform admin + the only building admin
  bool selfReviewAllowed = true; // building.settings.allow_admin_self_review
  String joinCodeValue = joinCode;

  final buildingName = const Bi('הרצל 12', 'Herzl 12');
  final buildingAddress = const Bi('הרצל 12, תל אביב', '12 Herzl St, Tel Aviv');

  final apartments = <String>[
    for (final f in [1, 2, 3, 4, 5, 6])
      for (final u in ['01', '02', '03', '04']) '$f$u',
    '12',
  ];
  final spaceLabels = <String>[for (var i = 1; i <= 24; i++) 'P${i.toString().padLeft(2, '0')}'];

  // ---- data -------------------------------------------------------------------------
  final people = <String, Person>{};
  final listings = <ParkingListing>[];
  final reservations = <Reservation>[];
  final requests = <DeliveryRequest>[];
  final txns = <Txn>[];
  final assignments = <Assignment>[];
  final notifications = <AppNotification>[];
  final applications = <ApplicationItem>[];
  final assignmentRequests = <AssignmentRequestItem>[];
  final disputes = <Dispute>[];

  Person get me => people[meId]!;
  Person person(String id) => people[id]!;

  String _id(String p) => '$p${_seq++}';

  DateTime at(int dayOffset, int h, [int m = 0]) =>
      DateTime(t0.year, t0.month, t0.day + dayOffset, h, m);

  DateTime get _nextHour => DateTime(t0.year, t0.month, t0.day, t0.hour + 1);

  ParkingListing listing(String id) => listings.firstWhere((l) => l.id == id);
  Reservation reservation(String id) => reservations.firstWhere((r) => r.id == id);
  DeliveryRequest request(String id) => requests.firstWhere((r) => r.id == id);
  Txn txn(String id) => txns.firstWhere((t) => t.id == id);

  // ---- seed -------------------------------------------------------------------------
  void _seed() {
    Person p(String id, String fh, String fe, String lh, String le, int c,
            {double? r, int rc = 0, int done = 0, String apt = '', String phone = '', int since = 2026}) =>
        people[id] = Person(
          id: id,
          firstHe: fh,
          firstEn: fe,
          lastHe: lh,
          lastEn: le,
          colorIndex: c,
          rating: r,
          ratingCount: rc,
          completed: done,
          apartment: apt,
          phone: phone,
          memberSince: since,
        );

    p(meId, 'מתן', 'Matan', 'ל', 'L', 0, r: 4.9, rc: 21, done: 23, apt: '12', phone: '050-123-4567');
    p('dana', 'דנה', 'Dana', 'כ', 'K', 1, r: 4.8, rc: 12, done: 14, apt: '403', phone: '052-222-1010');
    p('yossi', 'יוסי', 'Yossi', 'מ', 'M', 4, r: 4.6, rc: 7, done: 9, apt: '205', phone: '054-555-3030');
    p('noa', 'נועה', 'Noa', 'ר', 'R', 3, r: 5.0, rc: 28, done: 31, apt: '301', phone: '050-777-8888');
    p('amir', 'אמיר', 'Amir', 'ק', 'K', 2, r: 4.7, rc: 10, done: 12, apt: '104', phone: '053-909-1212');
    p('rina', 'רינה', 'Rina', 'ש', 'S', 5, r: 4.9, rc: 15, done: 18, apt: '506', phone: '052-444-6060');
    p('eli', 'אלי', 'Eli', 'ב', 'B', 0, apt: '302', phone: '054-101-2020');

    // Parking assignments of the current user (P03 verified, P05 awaiting the admin).
    assignments
      ..add(Assignment(id: 'as1', spaceLabel: 'P03', status: AssignmentStatus.active))
      ..add(Assignment(id: 'as2', spaceLabel: 'P05', status: AssignmentStatus.requested));

    final h = _nextHour;
    listings.addAll([
      ParkingListing(
        id: 'l1',
        spaceLabel: 'P07',
        ownerId: 'dana',
        start: h,
        end: h.add(const Duration(hours: 5)),
        priceMinor: 1000,
        description: const Bi('חניה מקורה ליד המעלית', 'Covered space next to the elevator'),
      ),
      ParkingListing(
        id: 'l2',
        spaceLabel: 'P12',
        ownerId: 'rina',
        start: at(1, 8),
        end: at(1, 20),
        priceMinor: 2500,
        instant: true,
        description: const Bi('כניסה קלה, מקום רחב', 'Easy entry, wide space'),
      ),
      ParkingListing(
        id: 'l3',
        spaceLabel: 'P21',
        ownerId: 'eli',
        start: at(3, 8),
        end: at(17, 20),
        priceMinor: 30000,
        description: const Bi('נוסע לחו״ל, זמין לשבועיים', 'Traveling abroad, free for two weeks'),
      ),
      ParkingListing(
        id: 'l4',
        spaceLabel: 'P03',
        ownerId: meId,
        start: at(1, 9),
        end: at(1, 19),
        priceMinor: 1500,
        description: const Bi('החניה שלי, ליד הכניסה', 'My space, near the entrance'),
      ),
      ParkingListing(
        id: 'l5',
        spaceLabel: 'P07',
        ownerId: 'dana',
        start: at(2, 7),
        end: at(2, 22),
        priceMinor: 2000,
      ),
      ParkingListing(
        id: 'l6',
        spaceLabel: 'P09',
        ownerId: 'dana',
        start: at(1, 10),
        end: at(1, 18),
        priceMinor: 1800,
        status: ListingStatus.reserved,
      ),
    ]);

    // Yossi asks for my listing (needs my response).
    reservations.add(Reservation(
      id: 'r1',
      listingId: 'l4',
      spaceLabel: 'P03',
      requesterId: 'yossi',
      ownerId: meId,
      start: at(1, 9),
      end: at(1, 19),
      priceMinor: 1500,
      createdAt: t0.subtract(const Duration(minutes: 25)),
      plate: '12-345-67',
      note: 'אני מגיע עם רכב קטן',
    ));

    // My confirmed reservation of Dana's P09 tomorrow; payment still pending.
    final t1 = Txn(
      id: 't1',
      type: TxType.parking,
      refId: 'r2',
      title: const Bi('P09'),
      payerId: meId,
      payeeId: 'dana',
      amountMinor: 1800,
      createdAt: t0.subtract(const Duration(hours: 3)),
      windowStart: at(1, 10),
      windowEnd: at(1, 18),
    );
    txns.add(t1);
    reservations.add(Reservation(
      id: 'r2',
      listingId: 'l6',
      spaceLabel: 'P09',
      requesterId: meId,
      ownerId: 'dana',
      start: at(1, 10),
      end: at(1, 18),
      priceMinor: 1800,
      createdAt: t0.subtract(const Duration(hours: 4)),
      status: ReservationStatus.confirmed,
      txId: 't1',
      plate: '55-123-88',
    ));

    // Delivery requests.
    requests.addAll([
      DeliveryRequest(
        id: 'd1',
        requesterId: 'noa',
        location: const Bi('קניון עזריאלי — לוקר Amazon', 'Azrieli Mall — Amazon locker'),
        description: const Bi('קופסה קטנה, כ־1 ק״ג', 'Small box, about 1 kg'),
        deadline: t0.add(const Duration(hours: 4)),
        rewardMinor: 1000,
        createdAt: t0.subtract(const Duration(minutes: 40)),
        handoffPlace: const Bi('לובי הבניין', 'Building lobby'),
        notes: const Bi('אפשר גם בשעות הערב', 'Evening is fine too'),
        pickupRef: 'AZ-77120',
      ),
      DeliveryRequest(
        id: 'd2',
        requesterId: 'amir',
        location: const Bi('דואר ישראל, רחוב הרצל 40', 'Israel Post, 40 Herzl St'),
        description: const Bi('מעטפה מיוחדת', 'Registered envelope'),
        deadline: at(1, 12),
        rewardMinor: 800,
        createdAt: t0.subtract(const Duration(hours: 2)),
        handoffPlace: const Bi('לובי הבניין', 'Building lobby'),
        doorAllowed: true,
        pickupRef: 'IL-3321',
      ),
      DeliveryRequest(
        id: 'd3',
        requesterId: meId,
        location: const Bi('לוקר Amazon, רחוב ויצמן 7', 'Amazon locker, 7 Weizmann St'),
        description: const Bi('חבילה בינונית', 'Medium parcel'),
        deadline: t0.add(const Duration(hours: 6)),
        rewardMinor: 1200,
        createdAt: t0.subtract(const Duration(hours: 1)),
        handoffPlace: const Bi('לובי הבניין', 'Building lobby'),
        pickupRef: 'LK-9921',
        status: RequestStatus.offerReceived,
        offers: [
          Offer(
            id: 'o1',
            helperId: 'amir',
            message: const Bi('אני בדרך לשם בשש, אביא לך', "I'm heading there at six, I'll bring it"),
            plannedAt: at(0, 18),
          ),
          Offer(
            id: 'o2',
            helperId: 'noa',
            message: const Bi('אפשר לאסוף עכשיו', 'I can pick it up right now'),
            plannedAt: _nextHour,
          ),
        ],
      ),
    ]);

    // Rina's request that I accepted as a helper (I am the courier).
    final d4 = DeliveryRequest(
      id: 'd4',
      requesterId: 'rina',
      location: const Bi('סניף דואר, דיזנגוף 120', 'Post office, 120 Dizengoff'),
      description: const Bi('חבילה קטנה', 'Small package'),
      deadline: t0.add(const Duration(hours: 5)),
      rewardMinor: 1200,
      createdAt: t0.subtract(const Duration(hours: 2)),
      handoffPlace: const Bi('לובי הבניין', 'Building lobby'),
      pickupRef: 'A-48213',
      status: RequestStatus.accepted,
      doorAllowed: false,
      offers: [Offer(id: 'o3', helperId: meId, status: OfferStatus.accepted, plannedAt: at(0, 17))],
    )
      ..helperId = meId
      ..txId = 't2'
      ..code = '4821';
    requests.add(d4);
    txns.add(Txn(
      id: 't2',
      type: TxType.delivery,
      refId: 'd4',
      title: d4.location,
      payerId: 'rina',
      payeeId: meId,
      amountMinor: 1200,
      createdAt: t0.subtract(const Duration(hours: 1)),
    ));

    // History: finished pickup waiting for payment confirmation by me (payee).
    final d5 = DeliveryRequest(
      id: 'd5',
      requesterId: 'noa',
      location: const Bi('לוקר BOX, אבן גבירול', 'BOX locker, Ibn Gabirol'),
      description: const Bi('שקית בגדים', 'Clothes bag'),
      deadline: t0.subtract(const Duration(days: 1)),
      rewardMinor: 1000,
      createdAt: t0.subtract(const Duration(days: 2)),
      status: RequestStatus.completed,
      handoffPlace: const Bi('לובי הבניין', 'Building lobby'),
    )
      ..helperId = meId
      ..txId = 't4'
      ..handoffMethod = HandoffMethod.code
      ..deliveredAt = t0.subtract(const Duration(hours: 20))
      ..code = '7305';
    requests.add(d5);
    txns.add(Txn(
      id: 't4',
      type: TxType.delivery,
      refId: 'd5',
      title: d5.location,
      payerId: 'noa',
      payeeId: meId,
      amountMinor: 1000,
      createdAt: t0.subtract(const Duration(days: 2)),
      status: TxStatus.awaitingSettlement,
      pay: PaymentStatus.payerConfirmed,
    )..serviceDoneAt = t0.subtract(const Duration(hours: 20)));

    // Completed parking transaction (history).
    txns.add(Txn(
      id: 't3',
      type: TxType.parking,
      refId: 'r3',
      title: const Bi('P21'),
      payerId: meId,
      payeeId: 'eli',
      amountMinor: 2000,
      createdAt: t0.subtract(const Duration(days: 9)),
      status: TxStatus.completed,
      pay: PaymentStatus.settled,
      windowStart: DateTime(t0.year, t0.month, t0.day - 8, 18),
      windowEnd: DateTime(t0.year, t0.month, t0.day - 8, 23),
    )
      ..serviceDoneAt = t0.subtract(const Duration(days: 8))
      ..completedAt = t0.subtract(const Duration(days: 8))
      ..ratedByMe = true);

    // Cancelled parking transaction (history).
    txns.add(Txn(
      id: 't5',
      type: TxType.parking,
      refId: 'r4',
      title: const Bi('P07'),
      payerId: meId,
      payeeId: 'dana',
      amountMinor: 1000,
      createdAt: t0.subtract(const Duration(days: 15)),
      status: TxStatus.cancelled,
      pay: PaymentStatus.cancelled,
      windowStart: DateTime(t0.year, t0.month, t0.day - 14, 18),
      windowEnd: DateTime(t0.year, t0.month, t0.day - 14, 23),
    ));

    // Notifications.
    void n(String type, Duration ago, {Map<String, String> params = const {}, String? route, bool read = false}) {
      notifications.add(AppNotification(
        id: _id('n'),
        type: type,
        time: t0.subtract(ago),
        params: params,
        route: route,
        read: read,
      ));
    }

    n('parking.request_received', const Duration(minutes: 25),
        params: {'name': 'yossi', 'space': 'P03'}, route: '/parking/my-listing/l4');
    n('payment.marked_paid', const Duration(hours: 3), params: {'name': 'noa'}, route: '/transaction/t4');
    n('delivery.offer_received', const Duration(minutes: 50),
        params: {'name': 'amir'}, route: '/packages/request/d3');
    n('rating.requested', const Duration(days: 8), params: {'name': 'eli'}, route: '/transaction/t3', read: true);
    n('verification.approved', const Duration(days: 30), route: '/home', read: true);

    // Admin data.
    applications.addAll([
      ApplicationItem(
        id: 'ap1',
        name: const Bi('טל בר', 'Tal Bar'),
        apartment: '204',
        phone: '050-880-1100',
        submittedAt: t0.subtract(const Duration(hours: 5)),
        spaces: ['P09'],
        spaceHeldByOther: true,
      ),
      ApplicationItem(
        id: 'ap2',
        name: const Bi('עומר דהן', 'Omer Dahan'),
        apartment: '12',
        phone: '052-300-4040',
        submittedAt: t0.subtract(const Duration(days: 1, hours: 2)),
        secondResident: true,
      ),
      ApplicationItem(
        id: 'ap3',
        name: const Bi('שיר אברהם', 'Shir Avraham'),
        apartment: '305',
        phone: '054-720-5566',
        submittedAt: t0.subtract(const Duration(days: 2)),
        spaces: ['P14'],
      ),
    ]);
    assignmentRequests.addAll([
      AssignmentRequestItem(
        id: 'ar_me',
        residentName: const Bi('מתן לוי', 'Matan Levy'),
        apartment: '12',
        spaceLabel: 'P05',
        isMine: true,
      ),
      AssignmentRequestItem(
        id: 'ar2',
        residentName: const Bi('טל בר', 'Tal Bar'),
        apartment: '204',
        spaceLabel: 'P09',
        heldByOther: true,
      ),
    ]);
    disputes.add(Dispute(
      id: 'dp1',
      txId: 't3',
      reasonKey: 'space_occupied',
      description: 'כשהגעתי החניה הייתה תפוסה ברכב אחר.',
      createdAt: t0.subtract(const Duration(hours: 30)),
    ));
  }

  // ---- notifications ----------------------------------------------------------------
  void notify(String type, {Map<String, String> params = const {}, String? route}) {
    notifications.insert(
      0,
      AppNotification(id: _id('n'), type: type, time: DateTime.now(), params: params, route: route),
    );
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  void markAllRead() {
    for (final n in notifications) {
      n.read = true;
    }
  }

  // ---- access flow ------------------------------------------------------------------
  void submitApplication({required String name, required String apartment, required List<String> spaces}) {
    applications.insert(
      0,
      ApplicationItem(
        id: 'ap_me',
        name: Bi(name, name),
        apartment: apartment,
        phone: me.phone,
        submittedAt: DateTime.now(),
        spaces: spaces,
        isMine: true,
        secondResident: false,
      ),
    );
    stage = AuthStage.pending;
  }

  /// Admin decision on an application. The sole admin may approve their own application
  /// while `allow_admin_self_review` is on (BR-A6) — the UI flags it.
  bool decideApplication(String id, ApplicationStatus status) {
    final a = applications.firstWhere((x) => x.id == id);
    if (a.isMine && !selfReviewAllowed) return false;
    a.status = status;
    if (a.isMine && status == ApplicationStatus.approved) stage = AuthStage.approved;
    return true;
  }

  // ---- assignments ------------------------------------------------------------------
  void requestAssignment(String space) {
    assignments.add(Assignment(id: _id('as'), spaceLabel: space, status: AssignmentStatus.requested));
    assignmentRequests.add(AssignmentRequestItem(
      id: _id('ar'),
      residentName: const Bi('מתן לוי', 'Matan Levy'),
      apartment: '12',
      spaceLabel: space,
      isMine: true,
    ));
  }

  void withdrawAssignment(String id) => assignments.removeWhere((a) => a.id == id);

  List<String> get myActiveSpaces =>
      assignments.where((a) => a.status == AssignmentStatus.active).map((a) => a.spaceLabel).toList();

  void decideAssignment(String id, bool approve) {
    final r = assignmentRequests.firstWhere((x) => x.id == id);
    r.status = approve ? AssignmentStatus.active : AssignmentStatus.rejected;
    if (r.isMine) {
      for (final a in assignments.where((a) => a.spaceLabel == r.spaceLabel)) {
        a.status = r.status;
      }
    }
  }

  // ---- parking ----------------------------------------------------------------------
  ParkingListing publishListing({
    required String space,
    required DateTime start,
    required DateTime end,
    required int priceMinor,
    String description = '',
    bool instant = false,
  }) {
    final l = ParkingListing(
      id: _id('l'),
      spaceLabel: space,
      ownerId: meId,
      start: start,
      end: end,
      priceMinor: priceMinor,
      description: Bi(description),
      instant: instant,
    );
    listings.insert(0, l);
    return l;
  }

  /// BR-D2 style overlap check for my own live listings of the same space.
  ParkingListing? overlappingListing(String space, DateTime start, DateTime end) {
    for (final l in listings) {
      final live = l.status == ListingStatus.available ||
          l.status == ListingStatus.reserved ||
          l.status == ListingStatus.active;
      if (l.spaceLabel == space && live && start.isBefore(l.end) && end.isAfter(l.start)) return l;
    }
    return null;
  }

  void cancelListing(String id) {
    final l = listing(id);
    l.status = ListingStatus.cancelled;
    for (final r in reservations.where((r) => r.listingId == id && r.status == ReservationStatus.requested)) {
      r.status = ReservationStatus.declined;
    }
  }

  /// Returns the reservation. Instant-book listings go straight to `confirmed` (BR-D10).
  Reservation requestParking(String listingId, {String plate = '', String note = ''}) {
    final l = listing(listingId);
    final r = Reservation(
      id: _id('r'),
      listingId: l.id,
      spaceLabel: l.spaceLabel,
      requesterId: meId,
      ownerId: l.ownerId,
      start: l.start,
      end: l.end,
      priceMinor: l.priceMinor,
      createdAt: DateTime.now(),
      plate: plate,
      note: note,
    );
    reservations.insert(0, r);
    if (l.instant) {
      _confirm(r);
    }
    return r;
  }

  List<Reservation> requestsFor(String listingId) =>
      reservations.where((r) => r.listingId == listingId).toList();

  void respondReservation(String id, bool accept) {
    final r = reservation(id);
    if (!accept) {
      r.status = ReservationStatus.declined;
      return;
    }
    r.status = ReservationStatus.accepted;
    r.expiresAt = DateTime.now().add(const Duration(hours: 2));
    listing(r.listingId).status = ListingStatus.reserved;
    for (final o in reservations.where((x) => x.listingId == r.listingId && x.id != id && x.status == ReservationStatus.requested)) {
      o.status = ReservationStatus.declined;
    }
    if (r.requesterId == meId) {
      notify('parking.request_accepted', params: {'name': r.ownerId, 'space': r.spaceLabel}, route: '/parking/reservation/${r.id}');
    }
  }

  void confirmReservation(String id) => _confirm(reservation(id));

  void _confirm(Reservation r) {
    r.status = ReservationStatus.confirmed;
    listing(r.listingId).status = ListingStatus.reserved;
    final t = Txn(
      id: _id('t'),
      type: TxType.parking,
      refId: r.id,
      title: Bi(r.spaceLabel),
      payerId: r.requesterId,
      payeeId: r.ownerId,
      amountMinor: r.priceMinor,
      createdAt: DateTime.now(),
      windowStart: r.start,
      windowEnd: r.end,
    );
    if (r.priceMinor == 0) t.pay = PaymentStatus.settled;
    txns.insert(0, t);
    r.txId = t.id;
  }

  void cancelReservation(String id) {
    final r = reservation(id);
    r.status = ReservationStatus.cancelled;
    final l = listing(r.listingId);
    if (r.ownerId == meId) {
      l.status = ListingStatus.cancelled;
    } else {
      l.status = ListingStatus.available;
    }
    if (r.txId != null) _cancelTx(txn(r.txId!));
  }

  /// Demo: the reservation window ends (system tick `confirmed → active → completed`).
  void completeReservation(String id) {
    final r = reservation(id);
    r.status = ReservationStatus.completed;
    listing(r.listingId).status = ListingStatus.completed;
    if (r.txId != null) {
      txn(r.txId!).serviceDoneAt = DateTime.now();
      _recompute(txn(r.txId!));
    }
  }

  // ---- packages ---------------------------------------------------------------------
  DeliveryRequest createRequest({
    required String location,
    required String description,
    required DateTime deadline,
    required int rewardMinor,
    String notes = '',
    String reference = '',
    Bi handoffPlace = const Bi('לובי הבניין', 'Building lobby'),
    bool doorAllowed = false,
  }) {
    final d = DeliveryRequest(
      id: _id('d'),
      requesterId: meId,
      location: Bi(location),
      description: Bi(description),
      deadline: deadline,
      rewardMinor: rewardMinor,
      createdAt: DateTime.now(),
      notes: Bi(notes),
      pickupRef: reference,
      handoffPlace: handoffPlace,
      doorAllowed: doorAllowed,
    );
    requests.insert(0, d);
    return d;
  }

  void makeOffer(String requestId, {String message = '', DateTime? plannedAt}) {
    final d = request(requestId);
    d.offers.add(Offer(id: _id('o'), helperId: meId, message: Bi(message), plannedAt: plannedAt));
  }

  void withdrawOffer(String requestId) {
    final d = request(requestId);
    for (final o in d.offers.where((o) => o.helperId == meId && o.status == OfferStatus.pending)) {
      o.status = OfferStatus.withdrawn;
    }
  }

  Offer? myOffer(DeliveryRequest d) {
    for (final o in d.offers) {
      if (o.helperId == meId && (o.status == OfferStatus.pending || o.status == OfferStatus.accepted)) return o;
    }
    return null;
  }

  /// Demo: a neighbor makes an offer on my request.
  void simulateOffer(String requestId) {
    final d = request(requestId);
    d.offers.add(Offer(
      id: _id('o'),
      helperId: 'amir',
      message: const Bi('אני בדרך לשם, אשמח לעזור', "I'm going there anyway, happy to help"),
      plannedAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    if (d.status == RequestStatus.open) d.status = RequestStatus.offerReceived;
    notify('delivery.offer_received', params: {'name': 'amir'}, route: '/packages/request/$requestId');
  }

  /// `respond_to_offer(accept)`: generates the handoff code, creates the transaction.
  void acceptOffer(String requestId, String offerId) {
    final d = request(requestId);
    for (final o in d.offers) {
      o.status = o.id == offerId ? OfferStatus.accepted : (o.status == OfferStatus.pending ? OfferStatus.rejected : o.status);
    }
    final o = d.offers.firstWhere((o) => o.id == offerId);
    d.status = RequestStatus.accepted;
    d.helperId = o.helperId;
    d.code = (1000 + _rng.nextInt(9000)).toString();
    final t = Txn(
      id: _id('t'),
      type: TxType.delivery,
      refId: d.id,
      title: d.location,
      payerId: d.requesterId,
      payeeId: o.helperId,
      amountMinor: d.rewardMinor,
      createdAt: DateTime.now(),
    );
    if (d.rewardMinor == 0) t.pay = PaymentStatus.settled;
    txns.insert(0, t);
    d.txId = t.id;
  }

  void cancelRequest(String id) {
    final d = request(id);
    d.status = RequestStatus.cancelled;
    for (final o in d.offers.where((o) => o.status == OfferStatus.pending)) {
      o.status = OfferStatus.expired;
    }
    if (d.txId != null) _cancelTx(txn(d.txId!));
  }

  void helperWithdraw(String id) {
    final d = request(id);
    for (final o in d.offers.where((o) => o.helperId == meId)) {
      o.status = OfferStatus.withdrawn;
    }
    d.helperId = null;
    d.status = RequestStatus.open;
    if (d.txId != null) _cancelTx(txn(d.txId!));
    d.txId = null;
  }

  void markCollected(String id) {
    final d = request(id);
    d.status = RequestStatus.collected;
    d.collectedAt = DateTime.now();
    if (d.requesterId == meId) return;
    notify('delivery.collected', params: {'name': d.helperId ?? ''}, route: '/packages/request/$id');
  }

  bool arrivalCooldown(DeliveryRequest d) =>
      d.arrivedAt != null && DateTime.now().difference(d.arrivedAt!) < const Duration(minutes: 10);

  void notifyArrival(String id) {
    request(id).arrivedAt = DateTime.now();
  }

  /// `confirm_handoff`: 5 wrong attempts lock the code for 15 minutes (BR-E5).
  CodeResult enterCode(String id, String code) {
    final d = request(id);
    final now = DateTime.now();
    if (d.lockedUntil != null && now.isBefore(d.lockedUntil!)) return CodeResult.locked;
    if (code == d.code) {
      d.failedAttempts = 0;
      d.handoffMethod = HandoffMethod.code;
      d.deliveredAt = now;
      d.status = RequestStatus.completed;
      _serviceDone(d);
      return CodeResult.ok;
    }
    d.failedAttempts += 1;
    if (d.failedAttempts >= 5) {
      d.failedAttempts = 0;
      d.lockedUntil = now.add(const Duration(minutes: 15));
      return CodeResult.locked;
    }
    return CodeResult.wrong;
  }

  int attemptsLeft(DeliveryRequest d) => 5 - d.failedAttempts;

  void regenerateCode(String id) {
    final d = request(id);
    if (d.regenCount >= 3) return;
    d.code = (1000 + _rng.nextInt(9000)).toString();
    d.regenCount += 1;
    d.failedAttempts = 0;
    d.lockedUntil = null;
  }

  void allowDoor(String id) => request(id).doorAllowed = true;

  /// `submit_door_delivery`: authorization + photo proof required (BR-E6/E10).
  bool submitDoorDelivery(String id, {String note = ''}) {
    final d = request(id);
    if (!d.doorAllowed) return false;
    final now = DateTime.now();
    d.status = RequestStatus.delivered;
    d.handoffMethod = HandoffMethod.doorPhoto;
    d.deliveredAt = now;
    d.proofAt = now;
    d.proofNote = note;
    d.autoConfirmAt = now.add(const Duration(hours: 24));
    if (d.requesterId != meId) {
      // nothing else: the requester is notified server-side
    }
    return true;
  }

  void confirmDelivery(String id) {
    final d = request(id);
    d.status = RequestStatus.completed;
    _serviceDone(d);
  }

  void _serviceDone(DeliveryRequest d) {
    if (d.txId == null) return;
    final t = txn(d.txId!);
    t.serviceDoneAt = DateTime.now();
    _recompute(t);
  }

  /// Demo: the helper arrives with my package.
  void simulateArrival(String id) {
    final d = request(id);
    d.arrivedAt = DateTime.now();
    notify('delivery.helper_arrived', params: {'name': d.helperId ?? ''}, route: '/packages/request/$id');
  }

  /// Demo: the helper takes my package from the pickup point.
  void simulateCollected(String id) => markCollected(id);

  /// Demo: the helper leaves the package by my door and uploads a photo (only if allowed).
  void simulateDoorDelivery(String id) {
    final d = request(id);
    if (!d.doorAllowed) return;
    submitDoorDelivery(id, note: 'הנחתי ליד הדלת, בצד הימני');
    notify('delivery.door_delivered', params: {'name': d.helperId ?? ''}, route: '/packages/request/$id');
  }

  // ---- transactions & mock payments -------------------------------------------------
  void paymentMarkPaid(String txId) {
    final t = txn(txId);
    if (t.pay != PaymentStatus.pending) return;
    t.pay = PaymentStatus.payerConfirmed;
    if (t.payeeId != meId) {
      notify('payment.marked_paid', params: {'name': t.payerId}, route: '/transaction/$txId');
    }
  }

  void paymentConfirmReceived(String txId) {
    final t = txn(txId);
    if (t.pay == PaymentStatus.settled || t.pay == PaymentStatus.cancelled) return;
    t.pay = PaymentStatus.settled;
    t.settledAt = DateTime.now();
    _recompute(t);
  }

  void paymentNotReceived(String txId) {
    final t = txn(txId);
    if (t.pay != PaymentStatus.payerConfirmed) return;
    t.pay = PaymentStatus.pending;
    t.notReceivedCount += 1;
  }

  void paymentWaive(String txId) {
    final t = txn(txId);
    if (t.pay == PaymentStatus.settled) return;
    t.pay = PaymentStatus.cancelled;
    _recompute(t);
  }

  void _cancelTx(Txn t) {
    if (t.status == TxStatus.completed || t.status == TxStatus.cancelled) return;
    t.status = TxStatus.cancelled;
    if (t.pay == PaymentStatus.settled) {
      t.refundRecord = true; // a separate refund record is created (BR-F7)
    } else {
      t.pay = PaymentStatus.cancelled;
    }
  }

  /// `app.recompute_transaction` (PRD §11.9).
  void _recompute(Txn t) {
    if (t.status == TxStatus.completed || t.status == TxStatus.cancelled || t.status == TxStatus.disputed) return;
    if (t.serviceDoneAt == null) return;
    final payDone = t.amountMinor == 0 || t.pay == PaymentStatus.settled || t.pay == PaymentStatus.cancelled;
    if (payDone) {
      t.status = TxStatus.completed;
      t.completedAt = DateTime.now();
      if (t.payerId == meId || t.payeeId == meId) {
        me.completed += 1;
        final other = t.payerId == meId ? t.payeeId : t.payerId;
        notify('rating.requested', params: {'name': other}, route: '/transaction/${t.id}');
      }
    } else {
      t.status = TxStatus.awaitingSettlement;
    }
  }

  // ---- ratings & disputes -----------------------------------------------------------
  void rate(String txId, int stars) {
    final t = txn(txId);
    t.ratedByMe = true;
    final other = person(t.payerId == meId ? t.payeeId : t.payerId);
    final total = (other.rating ?? 0) * other.ratingCount + stars;
    other.ratingCount += 1;
    other.rating = total / other.ratingCount;
  }

  void openDispute(String txId, String reasonKey, String description) {
    final t = txn(txId);
    if (t.status == TxStatus.inProgress || t.status == TxStatus.awaitingSettlement) {
      t.status = TxStatus.disputed;
    }
    disputes.insert(
      0,
      Dispute(id: _id('dp'), txId: txId, reasonKey: reasonKey, description: description, createdAt: DateTime.now()),
    );
  }

  void resolveDispute(String id) {
    final dp = disputes.firstWhere((d) => d.id == id);
    dp.resolved = true;
    final t = txn(dp.txId);
    if (t.status == TxStatus.disputed) {
      t.status = TxStatus.completed;
      t.completedAt = DateTime.now();
    }
  }

  // ---- derived views ----------------------------------------------------------------
  Txn? txnOfReservation(Reservation r) => r.txId == null ? null : txn(r.txId!);

  List<Txn> get myTxns =>
      txns.where((t) => t.payerId == meId || t.payeeId == meId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Transactions where I must act on the mock payment right now.
  List<Txn> get paymentActions => myTxns.where((t) {
        if (t.status == TxStatus.cancelled || t.status == TxStatus.completed) return false;
        if (t.amountMinor == 0) return false;
        if (t.payerId == meId) return t.pay == PaymentStatus.pending && t.status == TxStatus.awaitingSettlement;
        return t.pay == PaymentStatus.payerConfirmed;
      }).toList();

  int get pendingApplicationCount =>
      applications.where((a) => a.status == ApplicationStatus.pending).length;
}
