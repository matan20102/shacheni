import 'dart:async';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../data/building/board_read_store.dart';
import '../../data/building/building_repository.dart';
import 'glass_widgets.dart';

/// Chronological list with natural top alignment and an independent entry point.
class BoardTimeline extends StatefulWidget {
  const BoardTimeline({
    super.key,
    required this.buildingId,
    required this.posts,
    required this.readStore,
    required this.itemBuilder,
  });
  final String buildingId;
  final List<BoardPost> posts;
  final BoardReadStore readStore;
  final Widget Function(BoardPost) itemBuilder;
  @override
  State<BoardTimeline> createState() => BoardTimelineState();
}

class BoardTimelineState extends State<BoardTimeline>
    with WidgetsBindingObserver {
  final controller = ItemScrollController();
  final positions = ItemPositionsListener.create();
  BoardReadPosition? cursor;
  String? unreadPostId;
  bool ready = false, positioning = true;
  int generation = 0;
  Timer? readTimer;

  BoardReadPosition _position(BoardPost post) =>
      BoardReadPosition(post.createdAt, post.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    positions.itemPositions.addListener(_scheduleRead);
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++generation;
    readTimer?.cancel();
    BoardReadPosition? saved;
    try {
      saved = await widget.readStore.load(widget.buildingId);
    } catch (_) {
      /* A preference failure must not block the board. */
    }
    if (!mounted || request != generation) return;
    cursor = saved;
    final unread = saved == null
        ? -1
        : widget.posts.indexWhere(
            (p) => !p.mine && _position(p).compareTo(saved!) > 0,
          );
    setState(() {
      unreadPostId = unread < 0 ? null : widget.posts[unread].id;
      ready = true;
      positioning = true;
    });
    _afterPositions(
      () => _enter(unread < 0 ? widget.posts.length - 1 : unread, request),
    );
  }

  @override
  void didUpdateWidget(BoardTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId ||
        oldWidget.readStore != widget.readStore) {
      ready = false;
      positioning = true;
      unreadPostId = null;
      unawaited(_load());
    }
  }

  // The indexed list publishes item positions after its layout callback.
  void _afterPositions(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => action());
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool _valid(int request) =>
      mounted &&
      request == generation &&
      controller.isAttached &&
      widget.posts.isNotEmpty;

  bool get _allFit {
    final items = positions.itemPositions.value;
    final first = items.where((p) => p.index == 0).firstOrNull;
    final last = items
        .where((p) => p.index == widget.posts.length - 1)
        .firstOrNull;
    return first != null &&
        last != null &&
        first.itemLeadingEdge >= -.001 &&
        last.itemTrailingEdge <= 1.001;
  }

  void _enter(int index, int request) {
    if (!_valid(request)) return;
    if (_allFit) {
      _finishPositioning(request);
      return;
    }
    _positionAt(index, request);
  }

  void _positionAt(int index, int request) {
    if (!_valid(request)) return;
    controller.jumpTo(index: index.clamp(0, widget.posts.length - 1));
    _afterPositions(() {
      if (!_valid(request)) return;
      // Clamp to the natural end when fewer than one viewport follows the target.
      final last = positions.itemPositions.value
          .where((p) => p.index == widget.posts.length - 1)
          .firstOrNull;
      if (last != null && last.itemTrailingEdge < 1) {
        controller.jumpTo(
          index: index.clamp(0, widget.posts.length - 1),
          alignment: (1 - last.itemTrailingEdge).clamp(0, 1),
        );
      }
      _afterPositions(() => _finishPositioning(request));
    });
  }

  void _finishPositioning(int request) {
    if (!mounted || request != generation) return;
    setState(() => positioning = false);
    _scheduleRead();
  }

  void showLatest() {
    final request = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_valid(request)) return;
      if (_allFit) {
        _scheduleRead();
        return;
      }
      _positionAt(widget.posts.length - 1, request);
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _scheduleRead() {
    if (!ready || positioning || (readTimer?.isActive ?? false)) return;
    readTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted ||
          !ready ||
          positioning ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
      final visible = positions.itemPositions.value.where(
        (p) => p.itemLeadingEdge < 1 && p.itemTrailingEdge > 0,
      );
      BoardReadPosition? latest;
      for (final item in visible) {
        if (item.index >= widget.posts.length) continue;
        final value = _position(widget.posts[item.index]);
        if (latest == null || value.compareTo(latest) > 0) latest = value;
      }
      if (latest == null ||
          (cursor != null && latest.compareTo(cursor!) <= 0)) {
        return;
      }
      final building = widget.buildingId;
      try {
        await widget.readStore.save(building, latest);
        if (mounted && widget.buildingId == building) cursor = latest;
      } catch (_) {
        /* Retry after the next visible-position change. */
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    readTimer?.cancel();
    if (state == AppLifecycleState.resumed) _scheduleRead();
  }

  @override
  void dispose() {
    generation++;
    readTimer?.cancel();
    positions.itemPositions.removeListener(_scheduleRead);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: ValueKey('board-${widget.buildingId}'),
    child: !ready
        ? const SizedBox()
        : IgnorePointer(
            ignoring: positioning,
            child: Opacity(
              opacity: positioning ? 0 : 1,
              child: Align(
                alignment: Alignment.topCenter,
                child: ScrollablePositionedList.builder(
                  key: ValueKey('timeline-${widget.buildingId}'),
                  itemCount: widget.posts.length,
                  shrinkWrap: true,
                  itemScrollController: controller,
                  itemPositionsListener: positions,
                  padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                  itemBuilder: (context, i) => Column(
                    children: [
                      if (widget.posts[i].id == unreadPostId)
                        const Padding(
                          key: Key('board-unread-divider'),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'לא נקרא',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: glassMuted,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                        ),
                      widget.itemBuilder(widget.posts[i]),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}
