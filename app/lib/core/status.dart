import 'package:flutter/material.dart';

import '../data/models.dart';
import 'format.dart';
import 'widgets.dart';

typedef Status = ({String label, Tone tone});

Status listingStatusOf(BuildContext c, ListingStatus s) {
  final l = c.l10n;
  return switch (s) {
    ListingStatus.available => (label: l.statusAvailable, tone: Tone.success),
    ListingStatus.reserved => (label: l.statusReserved, tone: Tone.primary),
    ListingStatus.active => (label: l.statusActive, tone: Tone.primary),
    ListingStatus.completed => (label: l.statusCompleted, tone: Tone.neutral),
    ListingStatus.cancelled => (label: l.statusCancelled, tone: Tone.neutral),
    ListingStatus.expired => (label: l.statusExpired, tone: Tone.neutral),
  };
}

Status reservationStatusOf(BuildContext c, ReservationStatus s) {
  final l = c.l10n;
  return switch (s) {
    ReservationStatus.requested => (label: l.resRequested, tone: Tone.warn),
    ReservationStatus.accepted => (label: l.resAccepted, tone: Tone.accent),
    ReservationStatus.confirmed => (label: l.resConfirmed, tone: Tone.primary),
    ReservationStatus.active => (label: l.resActive, tone: Tone.primary),
    ReservationStatus.completed => (label: l.resCompleted, tone: Tone.success),
    ReservationStatus.cancelled => (label: l.statusCancelled, tone: Tone.neutral),
    ReservationStatus.declined => (label: l.statusDeclined, tone: Tone.danger),
    ReservationStatus.expired => (label: l.statusExpired, tone: Tone.neutral),
  };
}

/// Index in the 5-step reservation stepper (Request → Accepted → Booked → In use → Ended).
int reservationStep(ReservationStatus s) => switch (s) {
      ReservationStatus.requested => 0,
      ReservationStatus.accepted => 1,
      ReservationStatus.confirmed => 2,
      ReservationStatus.active => 3,
      ReservationStatus.completed => 4,
      _ => 0,
    };

Status requestStatusOf(BuildContext c, RequestStatus s) {
  final l = c.l10n;
  return switch (s) {
    RequestStatus.open => (label: l.reqOpen, tone: Tone.info),
    RequestStatus.offerReceived => (label: l.reqOffers, tone: Tone.accent),
    RequestStatus.accepted => (label: l.reqAccepted, tone: Tone.primary),
    RequestStatus.collected => (label: l.reqCollected, tone: Tone.primary),
    RequestStatus.delivered => (label: l.reqDelivered, tone: Tone.success),
    RequestStatus.completed => (label: l.reqCompleted, tone: Tone.success),
    RequestStatus.cancelled => (label: l.reqCancelled, tone: Tone.neutral),
    RequestStatus.expired => (label: l.reqExpired, tone: Tone.neutral),
    RequestStatus.disputed => (label: l.reqDisputed, tone: Tone.danger),
  };
}

int requestStep(RequestStatus s) => switch (s) {
      RequestStatus.open => 0,
      RequestStatus.offerReceived => 1,
      RequestStatus.accepted => 2,
      RequestStatus.collected => 3,
      RequestStatus.delivered => 4,
      RequestStatus.completed => 5,
      _ => 0,
    };

Status txStatusOf(BuildContext c, TxStatus s) {
  final l = c.l10n;
  return switch (s) {
    TxStatus.inProgress => (label: l.txInProgress, tone: Tone.primary),
    TxStatus.awaitingSettlement => (label: l.txAwaiting, tone: Tone.warn),
    TxStatus.completed => (label: l.txCompleted, tone: Tone.success),
    TxStatus.cancelled => (label: l.txCancelled, tone: Tone.neutral),
    TxStatus.disputed => (label: l.txDisputed, tone: Tone.danger),
  };
}

Status payStatusOf(BuildContext c, PaymentStatus s) {
  final l = c.l10n;
  return switch (s) {
    PaymentStatus.pending => (label: l.payPending, tone: Tone.warn),
    PaymentStatus.payerConfirmed => (label: l.payConfirmed, tone: Tone.info),
    PaymentStatus.settled => (label: l.paySettled, tone: Tone.success),
    PaymentStatus.cancelled => (label: l.payCancelled, tone: Tone.neutral),
  };
}

Status assignmentStatusOf(BuildContext c, AssignmentStatus s) {
  final l = c.l10n;
  return switch (s) {
    AssignmentStatus.active => (label: l.assignActive, tone: Tone.success),
    AssignmentStatus.requested => (label: l.assignRequested, tone: Tone.warn),
    AssignmentStatus.rejected => (label: l.assignRejected, tone: Tone.danger),
    AssignmentStatus.ended => (label: l.assignEnded, tone: Tone.neutral),
  };
}

String reasonLabel(BuildContext c, String key) {
  final l = c.l10n;
  return switch (key) {
    'space_occupied' => l.rSpaceOccupied,
    'not_delivered' => l.rNotDelivered,
    'payment_not_received' => l.rPaymentNotReceived,
    'requester_unreachable' => l.rUnreachable,
    _ => l.rOther,
  };
}

/// Renders a notification from its catalog code + params (PRD §13): the stored record has
/// no sentence, so a language switch re-renders history.
({String text, IconData icon, Tone tone}) renderNotification(
  BuildContext c,
  AppNotification n,
  Person Function(String id) person,
) {
  final l = c.l10n;
  String name() => person(n.params['name'] ?? DemoIds.me).shortName(c.lang);
  String space() => n.params['space'] ?? '';
  switch (n.type) {
    case 'parking.request_received':
      return (text: l.nParkingRequest(name(), space()), icon: Icons.directions_car_rounded, tone: Tone.accent);
    case 'parking.request_accepted':
      return (text: l.nParkingAccepted(name()), icon: Icons.check_circle_rounded, tone: Tone.success);
    case 'delivery.offer_received':
      return (text: l.nOfferReceived(name()), icon: Icons.local_offer_rounded, tone: Tone.accent);
    case 'delivery.collected':
      return (text: l.nCollected(name()), icon: Icons.inventory_2_rounded, tone: Tone.primary);
    case 'delivery.helper_arrived':
      return (text: l.nArrived(name()), icon: Icons.directions_walk_rounded, tone: Tone.accent);
    case 'delivery.door_delivered':
      return (text: l.nDoorDelivered, icon: Icons.photo_camera_rounded, tone: Tone.success);
    case 'payment.marked_paid':
      return (text: l.nMarkedPaid(name()), icon: Icons.payments_rounded, tone: Tone.info);
    case 'rating.requested':
      return (text: l.nRatingRequested(name()), icon: Icons.star_rounded, tone: Tone.accent);
    default:
      return (text: l.nApproved, icon: Icons.verified_rounded, tone: Tone.success);
  }
}

class DemoIds {
  static const me = 'me';
}
