import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/building/platform_repository.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';

@Preview(name: 'נייבור · ניהול המערכת', size: Size(390, 844))
Widget platformConsolePreview() => MaterialApp(
  theme: buildingTheme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: PlatformConsole(repository: _ConsolePreviewRepository()),
  ),
);

class _ConsolePreviewRepository extends PlatformRepository {
  @override
  Future<ConsolePage> load(
    ConsoleSection section,
    String query,
    int offset,
  ) async => ConsolePage([
    ConsoleItem(
      'preview',
      switch (section) {
        ConsoleSection.users => 'נועה לוי',
        ConsoleSection.buildings => 'הבית בגינה',
        ConsoleSection.applications => 'בקשת הצטרפות · נועה לוי',
        ConsoleSection.audit => 'ארכוב בניין',
      },
      'תצוגה מקדימה · נתוני הדגמה',
      switch (section) {
        ConsoleSection.users => const {
          'טלפון': '0501234567',
          'בניינים פעילים': '2',
        },
        ConsoleSection.buildings => const {
          'כתובת': 'הגפן 18, רמת גן',
          'מצב': 'פעיל',
          'דיירים': '24',
          'בקשות ממתינות': '2',
        },
        ConsoleSection.applications => const {
          'בניין': 'הבית בגינה',
          'דירה': '12',
          'אישור דירה': 'ממתין למנהל הדירה',
        },
        ConsoleSection.audit => const {'מנהל': 'נועה', 'סיבה': 'בניין הדגמה'},
      },
      switch (section) {
        ConsoleSection.buildings => const [ConsoleAction.archive],
        ConsoleSection.applications => const [ConsoleAction.approveBuilding],
        _ => const [],
      },
    ),
  ]);
  @override
  Future<void> act(ConsoleAction action, String id, String note) async {
    throw StateError('זוהי תצוגת עיצוב בלבד');
  }
}

class PlatformConsole extends StatefulWidget {
  const PlatformConsole({super.key, required this.repository, this.onChanged});
  final PlatformRepository repository;
  final Future<void> Function()? onChanged;
  @override
  State<PlatformConsole> createState() => _PlatformConsoleState();
}

class _PlatformConsoleState extends State<PlatformConsole> {
  late final vm = ConsoleViewModel(widget.repository)..load();
  final search = TextEditingController();
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    vm.dispose();
    super.dispose();
  }

  Future<void> action(ConsoleItem item, ConsoleAction action) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ConsoleActionDialog(
        item: item,
        action: action,
        onSave: (reason) => vm.act(action, item, reason),
      ),
    );
    if (saved == true) {
      try {
        await widget.onChanged?.call();
      } catch (_) {
        /* Next foreground sync retries. */
      }
    }
  }

  @override
  Widget build(BuildContext context) => GlassBackground(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('ניהול המערכת'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Text(
                      'משתמשים, בניינים ובקשות · שינויים נשמרים ביומן',
                      style: TextStyle(color: glassMuted),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        for (final section in ConsoleSection.values)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              key: ValueKey('console-${section.name}'),
                              label: Text(section.label),
                              selected: vm.section == section,
                              onSelected: vm.saving
                                  ? null
                                  : (_) {
                                      debounce?.cancel();
                                      vm.load(
                                        nextSection: section,
                                        search: search.text,
                                      );
                                    },
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextField(
                      key: const Key('console-search'),
                      controller: search,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'חיפוש',
                        prefixIcon: Icon(Icons.search_rounded),
                        counterText: '',
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        debounce = Timer(
                          const Duration(milliseconds: 350),
                          () => vm.load(search: value),
                        );
                      },
                    ),
                  ),
                  if (vm.loading) const LinearProgressIndicator(),
                  Expanded(
                    child: vm.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    buildingErrorMessage(vm.error!),
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        vm.load(nextOffset: vm.offset),
                                    child: const Text('ניסיון נוסף'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : vm.items.isEmpty && !vm.loading
                        ? const Center(child: Text('לא נמצאו תוצאות'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: vm.items.length,
                            itemBuilder: (context, index) {
                              final item = vm.items[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: GlassPanel(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (item.subtitle.isNotEmpty)
                                        SelectableText(
                                          item.subtitle,
                                          style: const TextStyle(
                                            color: glassMuted,
                                          ),
                                        ),
                                      const SizedBox(height: 10),
                                      for (final field in item.fields.entries)
                                        if (field.value.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              '${field.key}: ${field.value}',
                                            ),
                                          ),
                                      if (item.actions.isNotEmpty)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            for (final operation
                                                in item.actions)
                                              TextButton(
                                                onPressed: vm.saving
                                                    ? null
                                                    : () => action(
                                                        item,
                                                        operation,
                                                      ),
                                                child: Text(operation.label),
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: vm.loading || vm.saving || vm.offset == 0
                              ? null
                              : () => vm.load(nextOffset: vm.offset - 25),
                          child: const Text('הקודם'),
                        ),
                        Text('עמוד ${vm.offset ~/ 25 + 1}'),
                        TextButton(
                          onPressed: vm.loading || vm.saving || !vm.hasMore
                              ? null
                              : () => vm.load(nextOffset: vm.offset + 25),
                          child: const Text('הבא'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConsoleActionDialog extends StatefulWidget {
  const _ConsoleActionDialog({
    required this.item,
    required this.action,
    required this.onSave,
  });
  final ConsoleItem item;
  final ConsoleAction action;
  final Future<void> Function(String) onSave;
  @override
  State<_ConsoleActionDialog> createState() => _ConsoleActionDialogState();
}

class _ConsoleActionDialogState extends State<_ConsoleActionDialog> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(reason.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = buildingErrorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.action.label),
      content: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.item.title),
            const SizedBox(height: 10),
            Text(switch (widget.action) {
              ConsoleAction.archive =>
                'הבניין ייסגר לפעילות לכל הדיירים וההיסטוריה תישמר.',
              ConsoleAction.restore =>
                'הבניין יחזור לפעילות ולהצטרפות עם ההרשאות הקיימות.',
              ConsoleAction.approveBuilding => 'האישור הוא מטעם הבניין. בדירה עם מנהל נדרש גם אישור מנהל הדירה.',
            }),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('console-action-reason'),
              controller: reason,
              enabled: !saving,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'סיבת הפעולה'),
              maxLines: 3,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'יש לציין סיבה קצרה לפעולה'
                  : null,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          key: const Key('console-action-confirm'),
          onPressed: saving ? null : save,
          child: Text(saving ? 'שומר…' : 'אישור הפעולה'),
        ),
      ],
    ),
  );
}
