import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/demo_data.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/sheets.dart';

/// Stand-in for the delivery proof photo (the real app uploads the camera image to the
/// private `delivery-proofs` bucket — BR-E10). Draws a hallway, a door and a parcel.
class SamplePhoto extends StatelessWidget {
  const SamplePhoto({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PhotoPainter(), size: Size.infinite);
}

class _PhotoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // wall + floor
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFE9DFCF));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.74, w, h * 0.26), Paint()..color = const Color(0xFFBFB6A6));
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.72, w, h * 0.03),
      Paint()..color = const Color(0xFFD8CFBF),
    );
    // door
    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.08, w * 0.44, h * 0.66),
      const Radius.circular(4),
    );
    canvas.drawRRect(door, Paint()..color = const Color(0xFF7A4B2A));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.12, w * 0.36, h * 0.26),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8C5A36),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, h * 0.42, w * 0.36, h * 0.28),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF8C5A36),
    );
    canvas.drawCircle(Offset(w * 0.66, h * 0.46), h * 0.018, Paint()..color = const Color(0xFFD9B44A));
    // mat
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.30, h * 0.80, w * 0.40, h * 0.07), const Radius.circular(6)),
      Paint()..color = const Color(0xFF4F7C78),
    );
    // parcel
    final box = Rect.fromLTWH(w * 0.38, h * 0.62, w * 0.24, h * 0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(3)), Paint()..color = const Color(0xFFC9A06A));
    canvas.drawRect(
      Rect.fromLTWH(box.left + box.width * 0.44, box.top, box.width * 0.12, box.height),
      Paint()..color = const Color(0xFFE6CFA2),
    );
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, box.width, box.height * 0.16),
      Paint()..color = const Color(0x22000000),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// S29 — shows the honest set of delivery methods.
Future<void> showMethodsSheet(BuildContext context, WidgetRef ref, String id) {
  return showAppSheet<void>(context, builder: (ctx) {
    final l = ctx.l10n;
    final d = ref.read(demoProvider).data;
    final q = d.request(id);
    final requester = d.person(q.requesterId);
    final name = requester.shortName(ctx.lang);

    Widget option(IconData icon, String title, String hint, {VoidCallback? onTap, bool enabled = true, String? actionLabel}) {
      return AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: enabled ? onTap : null,
        color: enabled ? AppColors.surface : AppColors.surfaceAlt,
        child: Row(
          children: [
            Icon(icon, color: enabled ? AppColors.primary : AppColors.inkFaint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.bodyBold.copyWith(color: enabled ? AppColors.ink : AppColors.inkSoft)),
                  Text(hint, style: AppText.small),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(actionLabel, style: AppText.smallBold.copyWith(color: AppColors.primary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.methodsTitle, style: AppText.h2),
        const SizedBox(height: 14),
        option(Icons.call_rounded, l.methodPhone, l.methodPhoneHint, onTap: () {
          Navigator.pop(ctx);
          showSnack(context, '${l.call}: ${requester.phone}');
        }),
        if (q.doorAllowed)
          option(Icons.door_front_door_outlined, l.methodDoor, l.methodDoorHint, onTap: () {
            Navigator.pop(ctx);
            context.push('/packages/request/$id/door');
          })
        else
          option(Icons.door_front_door_outlined, l.methodDoor, l.methodDoorHint,
              enabled: true, actionLabel: l.askAllow(name), onTap: () {
            Navigator.pop(ctx);
            ref.read(demoProvider.notifier).act((d) => d.notifyArrival(id));
            showSnack(context, l.allowAsked(name));
          }),
        option(Icons.report_gmailerrorred_rounded, l.methodUnreachable, l.methodUnreachableHint, onTap: () {
          Navigator.pop(ctx);
          final tx = d.txn(q.txId!);
          showReportSheet(context, ref, tx, preset: 'requester_unreachable');
        }),
      ],
    );
  });
}

/// S30 — requester allows door delivery in-flight (arrival notification).
Future<void> showAllowDoorSheet(BuildContext context, WidgetRef ref, String id) {
  return showAppSheet<void>(context, builder: (ctx) {
    final l = ctx.l10n;
    final q = ref.read(demoProvider).data.request(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.allowSheetTitle, style: AppText.h2),
        const SizedBox(height: 10),
        Text(l.allowSheetBody, style: AppText.body),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: q.doorAllowed
              ? null
              : () {
                  ref.read(demoProvider.notifier).act((d) => d.allowDoor(id));
                  Navigator.pop(ctx);
                  showSnack(context, l.doorAllowedNote);
                },
          child: Text(l.allowLeaving),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l.showMyCode)),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.illComeDown)),
      ],
    );
  });
}

/// S28 — helper enters the requester's 4-digit code. 5 wrong attempts lock it for 15 min.
class CodeEntryScreen extends ConsumerStatefulWidget {
  const CodeEntryScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CodeEntryScreen> createState() => _CodeEntryScreenState();
}

class _CodeEntryScreenState extends ConsumerState<CodeEntryScreen> {
  String _code = '';
  bool _error = false;
  bool _delivered = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit() {
    final d = ref.read(demoProvider).data;
    late CodeResult result;
    ref.read(demoProvider.notifier).act((d) => result = d.enterCode(widget.id, _code));
    final q = d.request(widget.id);
    setState(() {
      _delivered = result == CodeResult.ok;
      _error = result != CodeResult.ok;
      if (result != CodeResult.ok) _code = '';
    });
    if (q.lockedUntil != null) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (q.lockedUntil == null || DateTime.now().isAfter(q.lockedUntil!)) {
          _timer?.cancel();
          _timer = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final q = d.request(widget.id);
    final who = d.person(q.requesterId);
    final name = who.shortName(context.lang);
    final locked = q.lockedUntil != null && DateTime.now().isBefore(q.lockedUntil!);

    if (_delivered) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 60, color: AppColors.success),
                ),
                const SizedBox(height: 22),
                Text(l.deliveredTitle, style: AppText.h1),
                const SizedBox(height: 8),
                Text(l.deliveredBody, style: AppText.body.copyWith(color: AppColors.inkSoft), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton(onPressed: () => context.pop(), child: Text(l.done)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.codeEntryTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  PersonAvatar(who, size: 48),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.codeEntryHint(name), style: AppText.bodyMedium)),
                ],
              ),
              const SizedBox(height: 26),
              CodeInput(
                value: _code,
                error: _error || locked,
                onChanged: locked ? (_) {} : (v) => setState(() {
                      _code = v;
                      _error = false;
                    }),
              ),
              const SizedBox(height: 14),
              if (locked)
                Text(l.lockedCode(fmtMmSs(q.lockedUntil!.difference(DateTime.now()))),
                    style: AppText.smallBold.copyWith(color: AppColors.danger), textAlign: TextAlign.center)
              else if (_error)
                Text(l.wrongCode('${d.attemptsLeft(q)}'),
                    style: AppText.smallBold.copyWith(color: AppColors.danger), textAlign: TextAlign.center),
              const Spacer(),
              FilledButton(
                onPressed: (_code.length == 4 && !locked) ? _submit : null,
                child: Text(l.confirmDelivery),
              ),
              TextButton(onPressed: () => showMethodsSheet(context, ref, widget.id), child: Text(l.cantHandOver)),
            ],
          ),
        ),
      ),
    );
  }
}

/// S42 — helper takes the proof photo (camera only in the real app) and submits the delivery.
class DoorPhotoScreen extends ConsumerStatefulWidget {
  const DoorPhotoScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DoorPhotoScreen> createState() => _DoorPhotoScreenState();
}

class _DoorPhotoScreenState extends ConsumerState<DoorPhotoScreen> {
  bool _taken = false;
  bool _done = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 60, color: AppColors.success),
                ),
                const SizedBox(height: 22),
                Text(l.doorPhotoSuccess, style: AppText.h2, textAlign: TextAlign.center),
                const SizedBox(height: 28),
                FilledButton(onPressed: () => context.pop(), child: Text(l.done)),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.doorPhotoTitle)),
      body: PageBody(
        children: [
          InfoBanner(l.doorPhotoGuide, icon: Icons.privacy_tip_outlined, tone: Tone.warn),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: _taken
                  ? const SamplePhoto()
                  : Container(
                      color: const Color(0xFF1B2B2A),
                      child: const Center(
                        child: Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 64),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.cameraDemoHint, style: AppText.tiny, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          if (!_taken)
            FilledButton.icon(
              onPressed: () => setState(() => _taken = true),
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(l.takePhoto),
            )
          else ...[
            TextField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: l.noteLabel)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                ref.read(demoProvider.notifier).act((d) => d.submitDoorDelivery(widget.id, note: _note.text.trim()));
                setState(() => _done = true);
              },
              child: Text(l.submitDelivery),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => setState(() => _taken = false), child: Text(l.retake)),
          ],
        ],
      ),
    );
  }
}

/// S43 — delivery photo viewer (requester / uploader; admin only during a dispute).
class PhotoViewerScreen extends ConsumerWidget {
  const PhotoViewerScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final d = ref.watch(demoProvider).data;
    final q = d.request(id);
    final helper = d.person(q.helperId ?? DemoData.meId);
    final iAmRequester = q.requesterId == DemoData.meId;
    return Scaffold(
      backgroundColor: const Color(0xFF111B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111B1A),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.photoViewerTitle, style: AppText.h2.copyWith(color: Colors.white)),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: const SizedBox.expand(child: SamplePhoto()),
            ),
          ),
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.photoMeta(helper.shortName(context.lang), fmtDayTime(context, q.proofAt ?? DateTime.now())),
                      style: AppText.small),
                  if ((q.proofNote ?? '').isNotEmpty) Text(l.photoNote(q.proofNote!), style: AppText.small),
                  const SizedBox(height: 4),
                  Text('${l.photoSample} · ${l.photoRetention}', style: AppText.tiny),
                  if (iAmRequester && q.status == RequestStatus.delivered) ...[
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        ref.read(demoProvider.notifier).act((d) => d.confirmDelivery(id));
                        context.pop();
                      },
                      child: Text(l.confirmReceived),
                    ),
                    TextButton.icon(
                      onPressed: () => showReportSheet(context, ref, d.txn(q.txId!)),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(l.reportProblem),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

