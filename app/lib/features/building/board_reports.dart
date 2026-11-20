import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';

/// Reported posts and replies for a building manager to resolve.
/// Renders nothing while there is nothing to review.
class BoardReportsPanel extends StatefulWidget {
  const BoardReportsPanel({
    super.key,
    required this.vm,
    required this.buildingId,
  });
  final BuildingViewModel vm;
  final String buildingId;
  @override
  State<BoardReportsPanel> createState() => _BoardReportsPanelState();
}

class _BoardReportsPanelState extends State<BoardReportsPanel> {
  List<BoardReport> reports = const [];
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final rows = await widget.vm.repository.reports(widget.buildingId);
      if (mounted) setState(() => reports = rows);
    } catch (failure) {
      if (mounted) setState(() => error = buildingErrorMessage(failure));
    }
  }

  Future<void> _resolve(BoardReport report, {required bool remove}) async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.vm.run(
        () => widget.vm.repository.resolveReport(report, remove: remove),
      );
      await _load();
    } catch (failure) {
      if (mounted) setState(() => error = buildingErrorMessage(failure));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty && error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'דיווחים על תוכן',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'שכנים ביקשו לבדוק את התוכן הזה. הכותב אינו רואה מי דיווח.',
            style: TextStyle(color: context.glass.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (saving) const LinearProgressIndicator(minHeight: 2),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: TextStyle(color: context.glass.error)),
            ),
          for (final report in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                key: ValueKey(
                  'report-${report.postId}-${report.replyId ?? 'post'}',
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.replyId == null ? 'פרסום' : 'תגובה'} של ${report.author} · ${report.count == 1 ? 'דיווח אחד' : '${report.count} דיווחים'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.glass.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(report.text),
                    for (final reason in report.reasons)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'סיבה: $reason',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.glass.muted,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.tonal(
                          key: ValueKey('report-remove-${report.postId}'),
                          onPressed: saving
                              ? null
                              : () => _resolve(report, remove: true),
                          child: const Text('הסרת התוכן'),
                        ),
                        TextButton(
                          key: ValueKey('report-keep-${report.postId}'),
                          onPressed: saving
                              ? null
                              : () => _resolve(report, remove: false),
                          child: const Text('התוכן בסדר'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
