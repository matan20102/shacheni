import 'dart:ui';

import 'package:flutter/material.dart';

const glassInk = Color(0xFF203B49);
const glassTeal = Color(0xFF087F8C);
const glassMuted = Color(0xFF657B88);
const glassError = Color(0xFFB53A40);

ThemeData buildingTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Heebo',
  colorScheme: ColorScheme.fromSeed(seedColor: glassTeal).copyWith(
    primary: glassTeal,
    error: glassError,
    surface: const Color(0xFFF8FCFD),
    onSurface: glassInk,
  ),
  scaffoldBackgroundColor: Colors.transparent,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      height: 1.2,
      color: glassInk,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: glassInk,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: glassInk,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: glassInk,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.6, color: glassInk),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: glassInk),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: glassMuted),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: .8),
    contentPadding: const EdgeInsets.all(17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFCCDDE3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFCCDDE3)),
    ),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFFF4FAFC),
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
  ),
);

/// Frosted layers remain bounded to navigation/cards; text sits on a legible tint.
/// Non-overlapping panels on one [GlassBackground] share backdrop input so the
/// engine can combine their blur operations. Overlapping panels must pass
/// [shareBackdrop] false to preserve the backdrop beneath each layer.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint = Colors.white,
    this.opacity = .7,
    this.radius = 26,
    this.shareBackdrop = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color tint;
  final double opacity, radius;
  final bool shareBackdrop;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D205A6A),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _blur(
        DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: .85),
              width: 1.2,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    ),
  );

  static final _filter = ImageFilter.blur(sigmaX: 18, sigmaY: 18);
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
      const Positioned.fill(child: RepaintBoundary(child: _Backdrop())),
      Positioned.fill(
        child: BackdropGroup(backdropKey: backdropKey, child: widget.child),
      ),
    ],
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFE2F4F4), Color(0xFFF2F6FB), Color(0xFFF6F0E9)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: -130,
          right: -100,
          child: _orb(const Color(0x553DCCC0), 410),
        ),
        Positioned(
          top: 360,
          left: -160,
          child: _orb(const Color(0x447C9CDD), 380),
        ),
        Positioned(
          bottom: -120,
          right: -80,
          child: _orb(const Color(0x44EBC7A7), 300),
        ),
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
            tint: const Color(0xFFB7E5E0),
            opacity: .55,
            shareBackdrop: false,
            child: Icon(
              Icons.apartment_rounded,
              size: size * .68,
              color: glassTeal,
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          left: 3,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glassTeal.withValues(alpha: .12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_rounded,
              size: size * .25,
              color: const Color(0xFFDC8D74),
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
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: .6,
      color: glassTeal,
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
  const SoftTag(this.text, {super.key, this.color = glassTeal, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
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
