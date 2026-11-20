import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/building/building_repository.dart';
import 'glass_widgets.dart';

/// Photos larger than this after scaling are refused (the bucket allows 2 MB).
const _maxBytes = 2 * 1024 * 1024;

String? _mimeFor(XFile file) {
  final type = file.mimeType;
  if (type != null && PostImage.mimeTypes.contains(type)) return type;
  final name = file.name.toLowerCase();
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  return null;
}

/// Chooses up to [PostImage.maxPerPost] photos for a new post.
class PostImagePicker extends StatefulWidget {
  const PostImagePicker({
    super.key,
    required this.images,
    required this.onChanged,
    this.enabled = true,
    this.picker,
  });
  final List<PostImage> images;
  final ValueChanged<List<PostImage>> onChanged;
  final bool enabled;

  /// Replaced in tests.
  final ImagePicker? picker;
  @override
  State<PostImagePicker> createState() => _PostImagePickerState();
}

class _PostImagePickerState extends State<PostImagePicker> {
  late final picker = widget.picker ?? ImagePicker();
  String? error;
  bool picking = false;

  int get _remaining => PostImage.maxPerPost - widget.images.length;

  Future<void> _pick(ImageSource source) async {
    if (picking || _remaining <= 0) return;
    setState(() {
      picking = true;
      error = null;
    });
    try {
      // Scaled down on the device before upload.
      const width = 1600.0, height = 1600.0;
      const quality = 80;
      final files = source == ImageSource.gallery && _remaining > 1
          ? await picker.pickMultiImage(
              maxWidth: width,
              maxHeight: height,
              imageQuality: quality,
              limit: _remaining,
            )
          : [
              ?await picker.pickImage(
                source: source,
                maxWidth: width,
                maxHeight: height,
                imageQuality: quality,
              ),
            ];
      final added = <PostImage>[];
      var skipped = false;
      for (final file in files.take(_remaining)) {
        final mime = _mimeFor(file);
        final bytes = mime == null ? null : await file.readAsBytes();
        if (mime == null || bytes == null || bytes.length > _maxBytes) {
          skipped = true;
          continue;
        }
        added.add(PostImage(bytes, mime));
      }
      if (!mounted) return;
      if (skipped) {
        error = 'חלק מהתמונות לא נוספו. אפשר לצרף JPG, PNG או WebP עד 2MB.';
      }
      if (added.isNotEmpty) widget.onChanged([...widget.images, ...added]);
    } catch (_) {
      if (mounted) error = 'לא הצלחנו לפתוח את התמונות. אפשר לנסות שוב.';
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.enabled && !picking && _remaining > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < widget.images.length; i++)
              Stack(
                key: Key('post-image-$i'),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      widget.images[i].bytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: Key('post-image-remove-$i'),
                        customBorder: const CircleBorder(),
                        onTap: widget.enabled
                            ? () => widget.onChanged([
                                ...widget.images.take(i),
                                ...widget.images.skip(i + 1),
                              ])
                            : null,
                        child: const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                            semanticLabel: 'הסרת התמונה',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_remaining > 0) ...[
              OutlinedButton.icon(
                key: const Key('post-image-gallery'),
                onPressed: canAdd ? () => _pick(ImageSource.gallery) : null,
                icon: picking
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  widget.images.isEmpty ? 'הוספת תמונות' : 'עוד תמונה',
                ),
              ),
              if (!kIsWeb)
                IconButton(
                  key: const Key('post-image-camera'),
                  onPressed: canAdd ? () => _pick(ImageSource.camera) : null,
                  tooltip: 'צילום תמונה',
                  icon: const Icon(Icons.photo_camera_outlined),
                ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          error ??
              'עד ${PostImage.maxPerPost} תמונות. התמונות יוקטנו לפני השליחה.',
          style: TextStyle(
            fontSize: 12,
            color: error == null ? glassMuted : glassError,
          ),
        ),
      ],
    );
  }
}

/// The photos of a post on the board, loaded through the repository.
class PostPhotos extends StatelessWidget {
  const PostPhotos({super.key, required this.paths, required this.load});
  final List<String> paths;
  final Future<Uint8List> Function(String path) load;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final single = paths.length == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 4.0;
          final side = single
              ? constraints.maxWidth
              : (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < paths.length; i++)
                SizedBox(
                  key: Key('post-photo-${paths[i]}'),
                  width: side,
                  height: single ? side * .62 : side * .75,
                  child: _Photo(
                    path: paths[i],
                    load: load,
                    onTap: () => _open(context, i),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _open(BuildContext context, int index) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView(
            controller: PageController(initialPage: index),
            children: [
              for (final path in paths)
                InteractiveViewer(
                  child: Center(
                    child: _Photo(path: path, load: load, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: SafeArea(
              child: IconButton(
                key: const Key('post-photo-close'),
                onPressed: () => Navigator.pop(ctx),
                tooltip: 'סגירה',
                color: Colors.white,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Photo extends StatefulWidget {
  const _Photo({
    required this.path,
    required this.load,
    this.onTap,
    this.fit = BoxFit.cover,
  });
  final String path;
  final Future<Uint8List> Function(String path) load;
  final VoidCallback? onTap;
  final BoxFit fit;
  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  late Future<Uint8List> bytes = widget.load(widget.path);

  @override
  void didUpdateWidget(_Photo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) bytes = widget.load(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snapshot) {
      final Widget child;
      if (snapshot.hasData) {
        child = Image.memory(
          snapshot.data!,
          fit: widget.fit,
          gaplessPlayback: true,
          semanticLabel: 'תמונה מהפרסום',
          errorBuilder: (_, _, _) => const _PhotoPlaceholder(failed: true),
        );
      } else {
        child = _PhotoPlaceholder(failed: snapshot.hasError);
      }
      final framed = ClipRRect(
        borderRadius: BorderRadius.circular(widget.onTap == null ? 0 : 12),
        child: child,
      );
      return widget.onTap == null
          ? framed
          : GestureDetector(
              onTap: snapshot.hasError
                  ? () => setState(() => bytes = widget.load(widget.path))
                  : widget.onTap,
              child: framed,
            );
    },
  );
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.failed = false});
  final bool failed;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x14000000),
    child: Center(
      child: failed
          ? const Icon(
              Icons.refresh_rounded,
              color: glassMuted,
              semanticLabel: 'טעינת התמונה נכשלה. הקשה לניסיון חוזר',
            )
          : const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
    ),
  );
}
