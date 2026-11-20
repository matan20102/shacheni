import 'dart:ui';

import 'package:flutter/material.dart';

/// Light-theme values, kept for code that has no [BuildContext] (e.g. the
/// printable lobby notice, which is always on white). Widgets inside the app
/// use [GlassContext.glass] so they follow light/dark mode.
const glassInk = Color(0xFF17303C);
const glassTeal = Color(0xFF066E7A);
const glassMuted = Color(0xFF4B626E);
const glassError = Color(0xFFB53A40);

/// Spacing scale: every gap and padding comes from these steps.
abstract final class Space {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 28.0;
}

/// Corner radii for the glass surfaces.
abstract final class Corners {
  static const chip = 14.0, control = 18.0, card = 22.0, panel = 26.0;
}

/// Colors of the Liquid Glass design, one set per brightness.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.brightness,
    required this.background,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.error,
    required this.glass,
    required this.glassStrong,
    required this.glassMine,
    required this.glassAccent,
    required this.border,
    required this.highlight,
    required this.shadow,
    required this.chip,
    required this.rule,
    required this.sheet,
    required this.gradient,
    required this.blobs,
    required this.warm,
  });
  final Brightness brightness;
  final Color background, ink, muted, accent, onAccent, error;

  /// Glass fills: ordinary card, emphasised surface (nav, sheets), the
  /// resident's own posts, and an accent-tinted hero card.
  final Color glass, glassStrong, glassMine, glassAccent;
  final Color border, highlight, shadow, chip, rule, sheet;
  final List<Color> gradient, blobs;

  /// Warm accent used for small decorative touches (the heart in the logo).
  final Color warm;

  bool get dark => brightness == Brightness.dark;

  static const light = GlassTokens(
    brightness: Brightness.light,
    background: Color(0xFFEAF2F1),
    ink: glassInk,
    muted: glassMuted,
    accent: glassTeal,
    onAccent: Colors.white,
    error: glassError,
    glass: Color(0x8FFFFFFF),
    glassStrong: Color(0xBDFFFFFF),
    glassMine: Color(0xB8D6F0EC),
    glassAccent: Color(0x9EC4E9E5),
    border: Color(0xD9FFFFFF),
    highlight: Color(0xF2FFFFFF),
    shadow: Color(0x1A17303C),
    chip: Color(0x1F066E7A),
    rule: Color(0x59066E7A),
    sheet: Color(0xFFF4FAFA),
    gradient: [Color(0xFFE2F4F2), Color(0xFFEFF4F8), Color(0xFFF6F0E9)],
    blobs: [Color(0x8C86D5CD), Color(0x66F5C68A), Color(0x73AFC7F3)],
    warm: Color(0xFFDC8D74),
  );

  static const darkTokens = GlassTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0E1A20),
    ink: Color(0xFFE8F1F2),
    muted: Color(0xFFA9BCC4),
    accent: Color(0xFF5CCAD4),
    onAccent: Color(0xFF06252A),
    error: Color(0xFFFF9A9E),
    glass: Color(0x8C1E2C34),
    glassStrong: Color(0xBD24343D),
    glassMine: Color(0x9E20565C),
    glassAccent: Color(0x9E1C4A50),
    border: Color(0x24FFFFFF),
    highlight: Color(0x29FFFFFF),
    shadow: Color(0x73000000),
    chip: Color(0x295CCAD4),
    rule: Color(0x595CCAD4),
    sheet: Color(0xFF15242B),
    gradient: [Color(0xFF0C1C21), Color(0xFF0E1A20), Color(0xFF14191F)],
    blobs: [Color(0x991E6D72), Color(0x736E4A1C), Color(0x802B4675)],
    warm: Color(0xFFE8A48E),
  );

  static GlassTokens of(Brightness b) =>
      b == Brightness.dark ? darkTokens : light;

  @override
  GlassTokens copyWith() => this;

  @override
  GlassTokens lerp(GlassTokens? other, double t) =>
      other == null || t < .5 ? this : other;
}

extension GlassContext on BuildContext {
  GlassTokens get glass =>
      Theme.of(this).extension<GlassTokens>() ?? GlassTokens.light;

  /// True when the device asks for less see-through UI. Glass then turns
  /// into solid surfaces without blur.
  bool get solidGlass => MediaQuery.maybeHighContrastOf(this) ?? false;
}

ThemeData buildingTheme([Brightness brightness = Brightness.light]) {
  final t = GlassTokens.of(brightness);
  TextStyle style(double size, FontWeight weight, {double? height, Color? c}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: c ?? t.ink,
      );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Corners.control),
    borderSide: BorderSide(color: t.rule.withValues(alpha: .45)),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Heebo',
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: glassTeal,
          brightness: brightness,
        ).copyWith(
          primary: t.accent,
          onPrimary: t.onAccent,
          error: t.error,
          surface: t.sheet,
          onSurface: t.ink,
          onSurfaceVariant: t.muted,
          secondaryContainer: t.chip,
          onSecondaryContainer: t.ink,
          outline: t.rule,
        ),
    extensions: [t],
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: IconThemeData(color: t.ink),
    dividerTheme: DividerThemeData(color: t.rule.withValues(alpha: .35)),
    textTheme: TextTheme(
      headlineLarge: style(34, FontWeight.w800, height: 1.2),
      headlineMedium: style(28, FontWeight.w700),
      headlineSmall: style(24, FontWeight.w700),
      titleLarge: style(21, FontWeight.w700),
      titleMedium: style(16, FontWeight.w600),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400, height: 1.6),
      bodyMedium: style(14, FontWeight.w400, height: 1.5),
      bodySmall: style(12, FontWeight.w400, height: 1.5, c: t.muted),
      labelLarge: style(14, FontWeight.w600),
      labelMedium: style(12, FontWeight.w600),
      labelSmall: style(11, FontWeight.w600, c: t.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: const TextStyle(
          fontFamily: 'Heebo',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.control),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.glassStrong,
      contentPadding: const EdgeInsets.all(17),
      border: border,
      enabledBorder: border,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.sheet,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.card),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.dark ? t.sheet : glassInk,
      contentTextStyle: TextStyle(
        fontFamily: 'Heebo',
        color: t.dark ? t.ink : Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.chip),
      ),
    ),
  );
}

/// Which glass fill a [GlassPanel] uses.
enum GlassTone { regular, strong, mine, accent }

/// The Liquid Glass material: a translucent fill over a blurred, more
/// saturated backdrop, a thin bright border with a highlight on the top edge,
/// and a soft shadow. With "increase contrast" on, it becomes a solid surface.
///
/// Non-overlapping panels on one [GlassBackground] share backdrop input so the
/// engine can combine their blur operations. Overlapping panels must pass
/// [shareBackdrop] false to preserve the backdrop beneath each layer.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.tone = GlassTone.regular,
    this.faded = false,
    this.radius = Corners.panel,
    this.shareBackdrop = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final GlassTone tone;

  /// Quieter look for finished items (e.g. a resolved request).
  final bool faded;
  final double radius;
  final bool shareBackdrop;

  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    final solid = context.solidGlass;
    var fill = switch (tone) {
      GlassTone.regular => t.glass,
      GlassTone.strong => t.glassStrong,
      GlassTone.mine => t.glassMine,
      GlassTone.accent => t.glassAccent,
    };
    if (faded) fill = fill.withValues(alpha: fill.a * .7);
    if (solid) fill = Color.alphaBlend(fill.withValues(alpha: 1), t.sheet);
    final shape = BorderRadius.circular(radius);
    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(
          color: solid ? t.rule : t.border,
          width: solid ? 1.4 : 1,
        ),
      ),
      child: Stack(
        children: [
          Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
          if (!solid)
            Positioned(
              top: 0,
              left: radius * .6,
              right: radius * .6,
              height: 1,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        t.highlight.withValues(alpha: 0),
                        t.highlight,
                        t.highlight.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (!solid) surface = _blur(surface);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: t.shadow.withValues(alpha: t.shadow.a * (faded ? .5 : 1)),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: shape, child: surface),
    );
  }

  /// Blur 22 with saturation 1.7, as in the approved mockup.
  static final _filter = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
    inner: const ColorFilter.matrix(_saturate),
  );
  static const _saturate = <double>[
    1.5512, -.5006, -.0505, 0, 0, //
    -.1488, 1.1994, -.0505, 0, 0, //
    -.1488, -.5006, 1.6495, 0, 0, //
    0, 0, 0, 1, 0,
  ];
  Widget _blur(Widget child) => shareBackdrop
      ? BackdropFilter.grouped(filter: _filter, child: child)
      : BackdropFilter(filter: _filter, child: child);
}

class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;
  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground> {
  // Keep the shared backdrop input identity stable across screen rebuilds.
  final backdropKey = BackdropKey();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: RepaintBoundary(child: _Backdrop(context.glass))),
      Positioned.fill(
        child: BackdropGroup(backdropKey: backdropKey, child: widget.child),
      ),
    ],
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop(this.t);
  final GlassTokens t;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: t.background,
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: t.gradient,
      ),
    ),
    child: Stack(
      children: [
        Positioned(top: -130, right: -100, child: _orb(t.blobs[0], 410)),
        Positioned(top: 360, left: -160, child: _orb(t.blobs[2], 380)),
        Positioned(bottom: -120, right: -80, child: _orb(t.blobs[1], 300)),
      ],
    ),
  );
  Widget _orb(Color color, double size) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// One look for "nothing here yet", "something failed" and "coming soon".
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.text,
    this.action,
    this.error = false,
  });
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    final color = error ? t.error : t.accent;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: Space.l),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (text != null) ...[
            const SizedBox(height: Space.s),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.muted, fontSize: 15, height: 1.6),
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.xl), action!],
        ],
      ),
    );
  }
}

/// Loading indicator in the accent color, optionally with a short label.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.glass.accent,
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: Space.m),
          Text(label!, style: TextStyle(color: context.glass.muted)),
        ],
      ],
    ),
  );
}

/// Floating glass tab bar. When [compact] (the user is scrolling down) it
/// narrows and shows icons only, giving the content more room.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });
  final List<(String, IconData)> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final t = context.glass;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return AnimatedPadding(
      duration: duration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        compact ? 70 : Space.l,
        Space.s,
        compact ? 70 : Space.l,
        Space.l,
      ),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        height: compact ? 56 : 68,
        child: GlassPanel(
          padding: const EdgeInsets.all(6),
          radius: 34,
          tone: GlassTone.strong,
          shareBackdrop: false,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selected,
                    button: true,
                    label: items[i].$1,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('nav-$i'),
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: duration,
                        decoration: BoxDecoration(
                          color: i == selected ? t.chip : Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        alignment: Alignment.center,
                        child: _item(items[i], i == selected, t),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item((String, IconData) item, bool on, GlassTokens t) {
    final color = on ? t.accent : t.muted;
    final icon = Icon(item.$2, size: 23, color: color);
    if (compact) return icon;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 2),
        Text(
          item.$1,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(
            fontSize: 11,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? t.ink : t.muted,
          ),
        ),
      ],
    );
  }
}

class BuildingMark extends StatelessWidget {
  const BuildingMark({super.key, this.size = 100});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 1.3,
    height: size * 1.3,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -.12,
          child: GlassPanel(
            radius: size * .28,
            padding: EdgeInsets.all(size * .18),
            tone: GlassTone.accent,
            shareBackdrop: false,
            child: Icon(
              Icons.apartment_rounded,
              size: size * .68,
              color: context.glass.accent,
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          left: 3,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.glass.sheet,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: context.glass.accent.withValues(alpha: .12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: size * .25,
              color: context.glass.warm,
            ),
          ),
        ),
      ],
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: context.glass.accent,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );
}

class SoftTag extends StatelessWidget {
  const SoftTag(this.text, {super.key, this.color, this.icon});
  final String text;
  final Color? color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.glass.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
