import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_error.dart';

/// A private message thread between a resident and the house committee.
@immutable
class InquirySummary {
  const InquirySummary({
    required this.id,
    required this.subject,
    required this.updatedAt,
    this.handled = false,
    this.preview = '',
    this.unread = false,
    this.author = '',
    this.apartment = '',
    this.mine = true,
  });
  final String id, subject, preview;

  /// Who wrote it; filled only in the committee's inbox.
  final String author, apartment;
  final bool handled, unread, mine;
  final DateTime updatedAt;
  factory InquirySummary.fromJson(Map<String, dynamic> j) => InquirySummary(
    id: j['id'] as String,
    subject: j['subject'] as String,
    handled: j['status'] == 'handled',
    preview: j['preview'] as String? ?? '',
    unread: j['unread'] == true,
    author: j['author'] as String? ?? '',
    apartment: j['apartment'] as String? ?? '',
    mine: j['mine'] as bool? ?? true,
    updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
  );
}

@immutable
class InquiryList {
  const InquiryList({
    this.isCommittee = false,
    this.mine = const [],
    this.inbox = const [],
    this.unread = 0,
  });
  final bool isCommittee;
  final List<InquirySummary> mine, inbox;

  /// Answers waiting for the resident, plus open inquiries waiting for the committee.
  final int unread;
  factory InquiryList.fromJson(Map<String, dynamic> j) => InquiryList(
    isCommittee: j['is_committee'] == true,
    mine: List.unmodifiable([
      for (final i in j['mine'] as List? ?? const [])
        InquirySummary.fromJson(i as Map<String, dynamic>),
    ]),
    inbox: List.unmodifiable([
      for (final i in j['inbox'] as List? ?? const [])
        InquirySummary.fromJson(i as Map<String, dynamic>),
    ]),
    unread: (j['unread'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class InquiryMessage {
  const InquiryMessage({
    required this.id,
    required this.body,
    required this.name,
    required this.createdAt,
    this.fromCommittee = false,
    this.mine = false,
  });
  final String id, body, name;
  final bool fromCommittee, mine;
  final DateTime createdAt;
  factory InquiryMessage.fromJson(Map<String, dynamic> j) => InquiryMessage(
    id: j['id'] as String,
    body: j['body'] as String,
    name: j['name'] as String? ?? '',
    fromCommittee: j['from_committee'] == true,
    mine: j['mine'] == true,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

@immutable
class InquiryThread {
  const InquiryThread({
    required this.id,
    required this.subject,
    this.handled = false,
    this.asCommittee = false,
    this.author = '',
    this.apartment = '',
    this.messages = const [],
  });
  final String id, subject, author, apartment;
  final bool handled;

  /// True when the caller reads it as the committee, not as its author.
  final bool asCommittee;
  final List<InquiryMessage> messages;
  factory InquiryThread.fromJson(Map<String, dynamic> j) => InquiryThread(
    id: j['id'] as String,
    subject: j['subject'] as String,
    handled: j['status'] == 'handled',
    asCommittee: j['side'] == 'committee',
    author: j['author'] as String? ?? '',
    apartment: j['apartment'] as String? ?? '',
    messages: List.unmodifiable([
      for (final m in j['messages'] as List? ?? const [])
        InquiryMessage.fromJson(m as Map<String, dynamic>),
    ]),
  );
}

abstract interface class InquiryRepository {
  Future<InquiryList> list(String buildingId);

  /// Opens one inquiry and marks it read for the caller.
  Future<InquiryThread> open(String inquiryId);
  Future<String> send(String buildingId, String subject, String body);
  Future<void> reply(String inquiryId, String body);

  /// The committee marks an inquiry handled, or opens it again.
  Future<void> setHandled(String inquiryId, bool handled);
}

class SupabaseInquiryRepository implements InquiryRepository {
  SupabaseInquiryRepository(this.client);
  final SupabaseClient client;
  @override
  Future<InquiryList> list(String buildingId) async => InquiryList.fromJson(
    await client.rpc('ba_inquiries', params: {'p_building': buildingId})
        as Map<String, dynamic>,
  );
  @override
  Future<InquiryThread> open(String inquiryId) async => InquiryThread.fromJson(
    await client.rpc('ba_inquiry', params: {'p_inquiry': inquiryId})
        as Map<String, dynamic>,
  );
  @override
  Future<String> send(String buildingId, String subject, String body) async =>
      await client.rpc(
        'ba_inquiry_open',
        params: {
          'p_building': buildingId,
          'p_subject': subject,
          'p_body': body,
        },
      ) as String;
  @override
  Future<void> reply(String inquiryId, String body) async {
    await client.rpc(
      'ba_inquiry_reply',
      params: {'p_inquiry': inquiryId, 'p_body': body},
    );
  }

  @override
  Future<void> setHandled(String inquiryId, bool handled) async {
    await client.rpc(
      'ba_inquiry_status',
      params: {
        'p_inquiry': inquiryId,
        'p_status': handled ? 'handled' : 'open',
      },
    );
  }
}

/// In-memory inquiries for previews and tests; never touches the server.
class LocalInquiryRepository implements InquiryRepository {
  LocalInquiryRepository({
    required this.apartmentFor,
    required this.isCommitteeFor,
    this.name = 'אני',
  });
  final String? Function(String buildingId) apartmentFor;
  final bool Function(String buildingId) isCommitteeFor;
  final String name;
  final _items = <_LocalInquiry>[];
  int _next = 0;

  String _apartment(String b) =>
      apartmentFor(b) ?? (throw StateError('ACCESS_DENIED'));
  _LocalInquiry _find(String id) {
    final i = _items.where((i) => i.id == id).firstOrNull;
    if (i == null) throw StateError('ACCESS_DENIED');
    _apartment(i.building);
    if (!i.mine && !isCommitteeFor(i.building)) {
      throw StateError('ACCESS_DENIED');
    }
    return i;
  }

  /// A neighbour writes to the committee; for previews and tests.
  String receive(
    String buildingId, {
    required String subject,
    required String body,
    String author = 'דנה לוי',
    String apartment = '2',
  }) {
    final i = _LocalInquiry(
      'inquiry-${++_next}',
      buildingId,
      subject,
      mine: false,
      author: author,
      apartment: apartment,
    )..messages.add(_msg(body, author, fromCommittee: false, mine: false));
    _items.add(i);
    return i.id;
  }

  /// The committee answers the caller's inquiry; for previews and tests.
  void answer(String inquiryId, String body) {
    final i = _items.firstWhere((i) => i.id == inquiryId);
    i.messages.add(_msg(body, 'הוועד', fromCommittee: true, mine: false));
    i.residentUnread = true;
  }

  InquiryMessage _msg(
    String body,
    String name, {
    required bool fromCommittee,
    required bool mine,
  }) => InquiryMessage(
    id: 'message-${++_next}',
    body: body,
    name: name,
    fromCommittee: fromCommittee,
    mine: mine,
    createdAt: DateTime.now(),
  );

  InquirySummary _summary(_LocalInquiry i, {required bool inbox}) =>
      InquirySummary(
        id: i.id,
        subject: i.subject,
        handled: i.handled,
        preview: i.messages.last.body,
        unread: inbox ? !i.mine && i.committeeUnread : i.residentUnread,
        author: inbox ? (i.mine ? name : i.author) : '',
        apartment: inbox ? (i.mine ? _apartment(i.building) : i.apartment) : '',
        mine: i.mine,
        updatedAt: i.messages.last.createdAt,
      );

  @override
  Future<InquiryList> list(String b) async {
    _apartment(b);
    final boss = isCommitteeFor(b);
    final here = _items.where((i) => i.building == b).toList().reversed;
    final inbox = boss
        ? ([for (final i in here) _summary(i, inbox: true)]..sort(
            (x, y) => x.handled == y.handled
                ? y.updatedAt.compareTo(x.updatedAt)
                : (x.handled ? 1 : -1),
          ))
        : <InquirySummary>[];
    return InquiryList(
      isCommittee: boss,
      mine: List.unmodifiable([
        for (final i in here)
          if (i.mine) _summary(i, inbox: false),
      ]),
      inbox: List.unmodifiable(inbox),
      unread: here
          .where(
            (i) =>
                (i.mine && i.residentUnread) ||
                (boss && !i.mine && !i.handled && i.committeeUnread),
          )
          .length,
    );
  }

  @override
  Future<InquiryThread> open(String id) async {
    final i = _find(id);
    final asCommittee = !i.mine;
    if (asCommittee) {
      i.committeeUnread = false;
    } else {
      i.residentUnread = false;
    }
    return InquiryThread(
      id: i.id,
      subject: i.subject,
      handled: i.handled,
      asCommittee: asCommittee,
      author: asCommittee ? i.author : '',
      apartment: asCommittee ? i.apartment : _apartment(i.building),
      messages: List.unmodifiable(i.messages),
    );
  }

  @override
  Future<String> send(String b, String subject, String body) async {
    _apartment(b);
    subject = subject.trim();
    body = body.trim();
    if (subject.isEmpty ||
        subject.length > 80 ||
        body.isEmpty ||
        body.length > 2000) {
      throw StateError('INVALID_ARGUMENT');
    }
    final i = _LocalInquiry('inquiry-${++_next}', b, subject)
      ..messages.add(_msg(body, name, fromCommittee: false, mine: true));
    _items.add(i);
    return i.id;
  }

  @override
  Future<void> reply(String id, String body) async {
    final i = _find(id);
    body = body.trim();
    if (body.isEmpty || body.length > 2000) {
      throw StateError('INVALID_ARGUMENT');
    }
    final asCommittee = !i.mine;
    i.messages.add(_msg(body, name, fromCommittee: asCommittee, mine: true));
    if (asCommittee) {
      i.residentUnread = true;
    } else {
      i
        ..handled = false
        ..committeeUnread = true;
    }
  }

  @override
  Future<void> setHandled(String id, bool handled) async {
    final i = _find(id);
    if (!isCommitteeFor(i.building)) throw StateError('ACCESS_DENIED');
    i.handled = handled;
  }
}

class _LocalInquiry {
  _LocalInquiry(
    this.id,
    this.building,
    this.subject, {
    this.mine = true,
    this.author = '',
    this.apartment = '',
  });
  final String id, building, subject, author, apartment;
  final bool mine;
  bool handled = false, residentUnread = false, committeeUnread = true;
  final messages = <InquiryMessage>[];
}

String inquiryError(Object error) {
  final message = error is PostgrestException
      ? error.message
      : error.toString();
  if (message.contains('INVALID_ARGUMENT')) return 'יש לכתוב נושא והודעה.';
  if (message.contains('TRY_LATER')) {
    return 'נשלחו הרבה פניות היום. אפשר להמשיך באחת הפניות הקיימות או לנסות שוב מחר.';
  }
  return buildingErrorMessage(error);
}
