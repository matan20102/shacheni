import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BoardReadPosition implements Comparable<BoardReadPosition> {
  const BoardReadPosition(this.createdAt, this.postId);
  final DateTime createdAt;
  final String postId;
  @override
  int compareTo(BoardReadPosition other) {
    final byTime = createdAt.compareTo(other.createdAt);
    return byTime == 0 ? postId.compareTo(other.postId) : byTime;
  }
}

abstract class BoardReadStore {
  Future<BoardReadPosition?> load(String buildingId);
  Future<void> save(String buildingId, BoardReadPosition position);
}

class MemoryBoardReadStore implements BoardReadStore {
  final positions = <String, BoardReadPosition>{};
  @override
  Future<BoardReadPosition?> load(String buildingId) async =>
      positions[buildingId];
  @override
  Future<void> save(String buildingId, BoardReadPosition position) async {
    final previous = positions[buildingId];
    if (previous == null || position.compareTo(previous) > 0) {
      positions[buildingId] = position;
    }
  }
}

/// Reading position is a device preference, isolated by account and building.
/// It contains no message text and never clears authentication preferences.
class DeviceBoardReadStore implements BoardReadStore {
  DeviceBoardReadStore(this.userId, {SharedPreferencesAsync? preferences})
    : preferences = preferences ?? SharedPreferencesAsync();
  final String userId;
  final SharedPreferencesAsync preferences;
  Future<void> _writes = Future.value();
  String _key(String buildingId) => 'naybor.board.read.$userId.$buildingId';
  @override
  Future<BoardReadPosition?> load(String buildingId) async {
    final raw = await preferences.getString(_key(buildingId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return BoardReadPosition(
        DateTime.parse(json['at'] as String),
        json['id'] as String,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> save(String buildingId, BoardReadPosition position) {
    final operation = _writes.then((_) async {
      final previous = await load(buildingId);
      if (previous != null && position.compareTo(previous) <= 0) return;
      await preferences.setString(
        _key(buildingId),
        jsonEncode({
          'at': position.createdAt.toUtc().toIso8601String(),
          'id': position.postId,
        }),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
