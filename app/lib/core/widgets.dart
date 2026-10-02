import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/tokens.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'format.dart';

enum Tone { neutral, primary, success, warn, danger, info, accent }

({Color fg, Color bg}) toneColors(Tone t) => switch (t) {
      Tone.neutral => (fg: AppColors.inkSoft, bg: AppColors.surfaceAlt),
      Tone.primary => (fg: AppColors.primary, bg: AppColors.primarySoft),
      Tone.success => (fg: AppColors.success, bg: AppColors.successSoft),
      Tone.warn => (fg: AppColors.warn, bg: AppColors.warnSoft),
      Tone.danger => (fg: AppColors.danger, bg: AppColors.dangerSoft),
      Tone.info => (fg: AppColors.info, bg: AppColors.infoSoft),
      Tone.accent => (fg: const Color(0xFFB45F10), bg: AppColors.accentSoft),
    };

/// Wide-screen preview shell: on desktop browsers the app is shown inside a phone-sized frame.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) return child;
      final h = math.min(c.maxHeight - 32, 880.0);
      return ColoredBox(
        color: const Color(0xFFDDD8CE),
        child: Center(
          child: Container(
            width: 410,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(34), child: child),
          ),
        ),
      );
    });
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor)),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.padding});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsetsDirectional.only(top: 22, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.h3)),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c.fg), const SizedBox(width: 4)],
          Flexible(child: Text(label, style: AppText.tiny.copyWith(color: c.fg, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.person, {super.key, this.size = 40});
  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.avatars[person.colorIndex % AppColors.avatars.length],
        shape: BoxShape.circle,
      ),
      child: Text(
        person.initial(context.lang),
        style: AppText.h3.copyWith(color: Colors.white, fontSize: size * 0.42),
      ),
    );
  }
}

/// ⭐ 4.9 (21) or "New neighbor".
class RatingText extends StatelessWidget {
  const RatingText(this.person, {super.key});
  final Person person;

  @override
  Widget build(BuildContext context) {
    if (person.isNew || person.rating == null) {
      return Text(context.l10n.newNeighbor, style: AppText.small);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
        const SizedBox(width: 2),
        Text(person.rating!.toStringAsFixed(1), style: AppText.smallBold.copyWith(color: AppColors.ink)),
        const SizedBox(width: 4),
        Text('(${person.ratingCount})', style: AppText.small),
      ],
    );
  }
}

class PersonLine extends StatelessWidget {
  const PersonLine(this.person, {super.key, this.trailing, this.onTap, this.size = 40, this.subtitle});
  final Person person;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double size;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Row(
        children: [
          PersonAvatar(person, size: size),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.shortName(context.lang), style: AppText.bodyBold),
                subtitle ?? RatingText(person),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(title, style: AppText.h2, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: AppText.body.copyWith(color: AppColors.inkSoft), textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.tone = Tone.info});
  final String text;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.small.copyWith(color: AppColors.ink, height: 1.4))),
        ],
      ),
    );
  }
}

/// Horizontal progress stepper. In Hebrew it flows right-to-left automatically.
class StepperBar extends StatelessWidget {
  const StepperBar({super.key, required this.labels, required this.current, this.failed = false});
  final List<String> labels;
  final int current;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final activeColor = failed ? AppColors.danger : AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0 ? Colors.transparent : (i <= current ? activeColor : AppColors.line),
                      ),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: i <= current ? activeColor : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: i <= current ? activeColor : AppColors.line, width: 2),
                      ),
                      child: i < current
                          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == labels.length - 1
                            ? Colors.transparent
                            : (i < current ? activeColor : AppColors.line),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.tiny.copyWith(
                    color: i == current ? AppColors.ink : AppColors.inkSoft,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.valueWidget});
  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.small)),
          Expanded(child: valueWidget ?? Text(value, style: AppText.bodyMedium)),
        ],
      ),
    );
  }
}

/// A dashed-looking "Demo:" button that simulates the other party's action.
class DemoButton extends ConsumerWidget {
  const DemoButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(demoToolsProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: AppColors.accentSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, size: 18, color: Color(0xFFB45F10)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label, style: AppText.smallBold.copyWith(color: const Color(0xFF8A4A0C))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill segmented control used for Find|Mine, Help|Mine, etc.
class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: i == index
                        ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: AppText.bodyBold.copyWith(
                      color: i == index ? AppColors.primary : AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 40});
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= value ? AppColors.accent : AppColors.inkFaint,
            ),
          ),
      ],
    );
  }
}

/// 4-digit code boxes + numeric keypad. Digits always run left-to-right, even in Hebrew.
class CodeInput extends StatelessWidget {
  const CodeInput({super.key, required this.value, required this.onChanged, this.length = 4, this.error = false, this.compact = false});
  final String value;
  final ValueChanged<String> onChanged;
  final int length;
  final bool error;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < length; i++)
                Container(
                  width: compact ? 44 : 58,
                  height: compact ? 56 : 68,
                  margin: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: error
                          ? AppColors.danger
                          : (i == value.length ? AppColors.primary : AppColors.line),
                      width: i == value.length ? 2 : 1.4,
                    ),
                  ),
                  child: Text(i < value.length ? value[i] : '', style: AppText.h1.copyWith(fontSize: 30)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '<'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      width: 84,
                      height: 52,
                      child: k.isEmpty
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.ink,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                              ),
                              onPressed: () {
                                if (k == '<') {
                                  if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
                                } else if (value.length < length) {
                                  onChanged(value + k);
                                }
                              },
                              child: k == '<'
                                  ? const Icon(Icons.backspace_outlined, size: 22)
                                  : Text(k, style: AppText.h2),
                            ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Large read-only code display used on the requester's handoff panel.
class CodeDisplay extends StatelessWidget {
  const CodeDisplay(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final ch in code.split(''))
            Container(
              width: 54,
              height: 66,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(ch, style: AppText.code),
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet helper with consistent padding and scroll handling.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: builder(ctx),
      ),
    ),
  );
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Standard scrolling page body with consistent gutters.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: children,
    );
  }
}

/// Soft illustration tile used on onboarding screens (icons composed on tinted shapes).
class HeroIllustration extends StatelessWidget {
  const HeroIllustration({super.key, this.icons = const [Icons.apartment_rounded]});
  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primarySoft, AppColors.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < icons.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: Icon(icons[i], size: 38, color: i.isEven ? AppColors.primary : AppColors.accent),
            ),
        ],
      ),
    );
  }
}


