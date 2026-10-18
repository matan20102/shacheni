import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ConsoleSection {
  users('משתמשים'),
  buildings('בניינים'),
  applications('בקשות'),
  audit('יומן פעולות');

  const ConsoleSection(this.label);
  final String label;
}

enum ConsoleAction {
  archive('ארכוב בניין'),
  restore('שחזור בניין'),
  approveBuilding('אישור מטעם הבניין');

  const ConsoleAction(this.label);
  final String label;
  String get wire => this == approveBuilding ? 'approve_building' : name;
}

@immutable
class ConsoleItem {
  const ConsoleItem(
    this.id,
    this.title,
    this.subtitle,
    this.fields,
    this.actions,
  );
  final String id, title, subtitle;
  final Map<String, String> fields;
  final List<ConsoleAction> actions;

  factory ConsoleItem.fromJson(ConsoleSection section, Map<String, dynamic> j) {
    String value(String key) => '${j[key] ?? ''}';
    return switch (section) {
      ConsoleSection.users => ConsoleItem(
        value('id'),
        value('name'),
        value('email'),
        {
          'טלפון': value('phone'),
          'בניינים פעילים': value('homes'),
          'הרשאה': j['is_admin'] == true ? 'מנהל מערכת' : 'משתמש',
        },
        const [],
      ),
      ConsoleSection.buildings => ConsoleItem(
        value('id'),
        value('name'),
        value('address'),
        {
          'מצב': j['archived'] == true
              ? 'בארכיון'
              : j['status'] == 'active'
              ? 'פעיל'
              : 'לא פעיל',
          'דיירים': value('residents'),
          'בקשות ממתינות': value('pending'),
          if (j['has_admin'] != true) 'ניהול': 'אין מנהל בניין מאושר',
        },
        [
          if (j['status'] == 'active') ConsoleAction.archive,
          if (j['archived'] == true && j['has_admin'] == true)
            ConsoleAction.restore,
        ],
      ),
      ConsoleSection.applications => ConsoleItem(
        value('id'),
        value('name'),
        '${value('building')} · דירה ${value('apartment')}',
        {
          'אישור בניין': j['building_approved'] == true ? 'התקבל' : 'ממתין',
          'אישור דירה': j['needs_apartment'] != true
              ? 'דירה חדשה — לא נדרש'
              : j['apartment_approved'] == true
              ? 'התקבל'
              : 'ממתין למנהל הדירה',
        },
        [if (j['building_approved'] != true) ConsoleAction.approveBuilding],
      ),
      ConsoleSection.audit => ConsoleItem(
        value('id'),
        auditLabel(value('action')),
        value('actor'),
        {
          'בניין': value('building'),
          'סיבה': value('note'),
          'מועד': value('created_at'),
          'מזהה יעד': value('target_id'),
        },
        const [],
      ),
    };
  }
}

String auditLabel(String action) =>
    const {
      'community.join': 'בקשת הצטרפות',
      'community.leave': 'יציאה מבניין',
      'community.approve_building': 'אישור הצטרפות מטעם הבניין',
      'community.approve_apartment': 'אישור הצטרפות מטעם הדירה',
      'community.archive': 'ארכוב בניין',
      'community.profile_updated': 'עריכת פרופיל',
      'community.building_admin_granted': 'מינוי מנהל בניין',
      'community.building_admin_revoked': 'הסרת הרשאת מנהל בניין',
      'community.console_archive': 'ארכוב בניין דרך ניהול המערכת',
      'community.console_restore': 'שחזור בניין דרך ניהול המערכת',
      'community.console_approve_building': 'אישור הצטרפות דרך ניהול המערכת',
      'community.platform_admin_granted': 'הענקת הרשאת מנהל מערכת',
      'community.apartment_admin_succession': 'העברת ניהול דירה',
    }[action] ??
    'פעולה: $action';

class ConsolePage {
  const ConsolePage(this.items, {this.hasMore = false});
  final List<ConsoleItem> items;
  final bool hasMore;
}

abstract class PlatformRepository {
  Future<ConsolePage> load(ConsoleSection section, String query, int offset);
  Future<void> act(ConsoleAction action, String id, String note);
}

class SupabasePlatformRepository implements PlatformRepository {
  SupabasePlatformRepository(this.client);
  final SupabaseClient client;
  @override
  Future<ConsolePage> load(
    ConsoleSection section,
    String query,
    int offset,
  ) async {
    final j = await client.rpc(
      'ba_console',
      params: {
        'p_kind': section.name,
        'p_query': query.trim(),
        'p_offset': offset,
      },
    ) as Map<String, dynamic>;
    return ConsolePage(
      List.unmodifiable(
        (j['items'] as List)
            .take(25)
            .map(
              (row) =>
                  ConsoleItem.fromJson(section, row as Map<String, dynamic>),
            ),
      ),
      hasMore: j['has_more'] == true,
    );
  }

  @override
  Future<void> act(ConsoleAction action, String id, String note) => client.rpc(
    'ba_console_action',
    params: {'p_action': action.wire, 'p_id': id, 'p_note': note.trim()},
  );
}

class ConsoleViewModel extends ChangeNotifier {
  ConsoleViewModel(this.repository);
  final PlatformRepository repository;
  ConsoleSection section = ConsoleSection.users;
  List<ConsoleItem> items = const [];
  String query = '';
  int offset = 0, _generation = 0;
  bool loading = false, saving = false, hasMore = false, _disposed = false;
  Object? error;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({
    ConsoleSection? nextSection,
    String? search,
    int? nextOffset,
  }) async {
    if (nextSection != null) section = nextSection;
    if (search != null) query = search;
    offset = nextOffset ?? 0;
    final generation = ++_generation;
    items = const [];
    hasMore = false;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.load(section, query, offset);
      if (_disposed || generation != _generation) return;
      items = result.items;
      hasMore = result.hasMore;
    } catch (e) {
      if (generation == _generation) error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> act(ConsoleAction action, ConsoleItem item, String note) async {
    if (saving) return;
    saving = true;
    _notify();
    try {
      await repository.act(action, item.id, note);
      await load(nextOffset: offset);
    } finally {
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
