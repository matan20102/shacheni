import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
  String get lang => Localizations.localeOf(this).languageCode;
  String get localeTag => Localizations.localeOf(this).toString();
}

/// Money is stored in agorot (`amount_minor`); shown as whole shekels when possible.
String fmtMoney(int minor) {
  final v = minor / 100;
  return '₪${v == v.roundToDouble() ? v.round() : v.toStringAsFixed(2)}';
}

String fmtAmount(int minor) {
  final v = minor / 100;
  return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);
}

String fmtTime(BuildContext c, DateTime d) => DateFormat.Hm(c.localeTag).format(d);

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String fmtDay(BuildContext c, DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return c.l10n.today;
  if (sameDay(d, now.add(const Duration(days: 1)))) return c.l10n.tomorrow;
  return DateFormat.MMMd(c.localeTag).format(d);
}

String fmtDayTime(BuildContext c, DateTime d) => c.l10n.dayAtTime(fmtDay(c, d), fmtTime(c, d));

String fmtWindow(BuildContext c, DateTime start, DateTime end) {
  if (sameDay(start, end)) {
    return c.l10n.windowSame(fmtDay(c, start), fmtTime(c, start), fmtTime(c, end));
  }
  return c.l10n.windowDiff(fmtDayTime(c, start), fmtDayTime(c, end));
}

/// "in 3h 20m" / "in 45 min"; negative → "Overdue".
String fmtCountdown(BuildContext c, DateTime target) {
  final diff = target.difference(DateTime.now());
  if (diff.isNegative) return c.l10n.overdue;
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  if (h == 0) return c.l10n.inM('${diff.inMinutes}');
  return c.l10n.inHM('$h', '$m');
}

/// Plain duration ("3h 20m" / "14:30") used for lock timers.
String fmtMmSs(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String fmtAgo(BuildContext c, DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return c.l10n.agoMinutes('${d.inMinutes < 1 ? 1 : d.inMinutes}');
  if (d.inHours < 24) return c.l10n.agoHours('${d.inHours}');
  return c.l10n.agoDays('${d.inDays}');
}
