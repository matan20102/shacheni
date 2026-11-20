import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/brand.dart';
import '../../app/config.dart';
import 'glass_widgets.dart';

/// QR code of the building's existing invitation link ([inviteLink]).
/// Scanning opens the app with the join code filled in; joining still needs approval.
class InviteQrCode extends StatelessWidget {
  const InviteQrCode({super.key, required this.code, this.size = 160});
  final String code;
  final double size;
  String get link => inviteLink(code);
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'קוד QR להצטרפות לבניין',
    image: true,
    child: QrImageView(
      data: link,
      size: size,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: glassInk),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: glassInk,
      ),
    ),
  );
}

/// Panel for building admins in "מידע וניהול הבניין".
class InviteQrPanel extends StatelessWidget {
  const InviteQrPanel({super.key, required this.name, required this.code});
  final String name, code;
  @override
  Widget build(BuildContext context) => GlassPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('הזמנה בסריקה', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.xs),
        Text(
          'שכנים שסורקים את הקוד מגיעים ישר לבקשת הצטרפות. הגישה נפתחת רק אחרי אישור.',
          style: TextStyle(fontSize: 12, color: context.glass.muted),
        ),
        const SizedBox(height: Space.l),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InviteQrCode(code: code),
          ),
        ),
        const SizedBox(height: Space.m),
        Center(
          child: TextButton.icon(
            key: const Key('invite-qr-poster'),
            onPressed: () => showInvitePoster(context, name: name, code: code),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('מודעה ללוח בלובי'),
          ),
        ),
      ],
    ),
  );
}

/// Full-screen, high-contrast notice for the lobby board: print it from the
/// browser or take a screenshot. Built on white so it prints cleanly.
Future<void> showInvitePoster(
  BuildContext context, {
  required String name,
  required String code,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => InvitePoster(name: name, code: code),
  ),
);

class InvitePoster extends StatelessWidget {
  const InvitePoster({super.key, required this.name, required this.code});
  final String name, code;
  @override
  Widget build(BuildContext context) {
    final link = inviteLink(code);
    // Printed on paper: always the light look, whatever the app mode.
    return Theme(
      data: buildingTheme(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: glassInk,
          title: const Text('מודעה ללוח בלובי'),
          actions: [
            IconButton(
              tooltip: 'העתקת הקישור',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('הקישור הועתק')));
                }
              },
              icon: const Icon(Icons.copy_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final qr = (box.biggest.shortestSide * .62).clamp(180.0, 420.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        Text(
                          'שכנים יקרים',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: Space.s),
                        Text(
                          'הצטרפו ל״$name״ ב$appNameHebrew: לוח הבניין, בקשות בין שכנים ושיתוף חניות.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: Space.xxl),
                        InviteQrCode(code: code, size: qr),
                        const SizedBox(height: Space.xl),
                        const Text(
                          'סורקים במצלמה של הטלפון ושולחים בקשת הצטרפות',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: glassInk),
                        ),
                        const SizedBox(height: Space.xl),
                        const Text(
                          'או מזינים באפליקציה את קוד הבניין',
                          style: TextStyle(fontSize: 13, color: glassMuted),
                        ),
                        SelectableText(
                          code,
                          key: const Key('invite-poster-code'),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            color: glassTeal,
                          ),
                        ),
                        const SizedBox(height: Space.s),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            link,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: glassMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
