import 'package:flutter/foundation.dart';

import 'building_repository.dart';

class ResidentDirectoryModel extends ChangeNotifier {
  ResidentDirectoryModel(this.building, this.buildingId);
  final BuildingViewModel building;
  final String buildingId;
  List<ResidentMember> members = const [];
  bool loading = true, saving = false, _disposed = false;
  Object? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      final rows = await building.repository.residents(buildingId);
      if (_disposed) return;
      members = rows;
      error = null;
    } catch (e) {
      members = const [];
      error = e;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> changeRole(ResidentMember member, bool admin) async {
    if (saving || _disposed) return;
    saving = true;
    error = null;
    _notify();
    try {
      await building.run(() => building.repository.setAdmin(member.id, admin));
      if (_disposed) return;
      await load();
    } catch (e) {
      error = e;
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
