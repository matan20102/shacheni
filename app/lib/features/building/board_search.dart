import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/building/building_repository.dart';
import '../../data/building/supabase_building_repository.dart';
import 'glass_widgets.dart';

/// Search and older posts, a page at a time. Read-only: the live board keeps
/// the recent posts and every action on them.
class BoardSearch extends StatefulWidget {
  const BoardSearch({
    super.key,
    required this.repository,
    required this.buildingId,
  });
  final BuildingRepository repository;
  final String buildingId;
  @override
  State<BoardSearch> createState() => _BoardSearchState();
}

class _BoardSearchState extends State<BoardSearch> {
  final query = TextEditingController();
  final posts = <BoardPost>[];
  Timer? debounce;
  bool loading = true, hasMore = false;
  String? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true, initial: true));
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    super.dispose();
  }

  void _queue() {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_load(reset: true)),
    );
  }

  Future<void> _load({required bool reset, bool initial = false}) async {
    final request = ++generation;
    // The first load starts from initState, where the fields are already set.
    if (!initial) {
      setState(() {
        loading = true;
        error = null;
        if (reset) posts.clear();
      });
    }
    try {
      final page = await widget.repository.boardPage(
        widget.buildingId,
        before: reset || posts.isEmpty ? null : posts.last.createdAt,
        query: query.text,
      );
      if (!mounted || request != generation) return;
      setState(() {
        // The first page repeats pinned posts; keep each post once.
        for (final post in page.posts) {
          if (!posts.any((shown) => shown.id == post.id)) posts.add(post);
        }
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        hasMore = page.hasMore;
        loading = false;
      });
    } catch (failure) {
      if (!mounted || request != generation) return;
      setState(() {
        error = buildingErrorMessage(failure);
        loading = false;
      });
    }
  }

  String _date(DateTime time) =>
      '\u2066${time.day}.${time.month}.${time.year % 100}\u2069';

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .8,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('חיפוש בלוח', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Space.m),
          TextField(
            key: const Key('board-search-query'),
            controller: query,
            maxLength: 60,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _queue(),
            onSubmitted: (_) => unawaited(_load(reset: true)),
            decoration: const InputDecoration(
              hintText: 'מילה מפרסום או מתגובה',
              prefixIcon: Icon(Icons.search_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: Space.m),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: TextStyle(color: context.glass.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_load(reset: posts.isEmpty)),
                    child: const Text('ניסיון נוסף'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              key: const Key('board-search-results'),
              children: [
                if (!loading && error == null && posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      query.text.trim().isEmpty
                          ? 'עוד אין פרסומים בלוח.'
                          : 'לא נמצאו פרסומים מתאימים.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.glass.muted),
                    ),
                  ),
                for (final post in posts)
                  Padding(
                    key: ValueKey('board-search-post-${post.id}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${post.author} · דירה ${post.apartment} · ${_date(post.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.glass.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: Space.s),
                          Text(post.text),
                          for (final reply in post.replies)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                top: 8,
                                start: 12,
                              ),
                              child: Text(
                                '${reply.mine ? 'אני' : reply.author}: ${reply.text}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.glass.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (hasMore && !loading)
                  TextButton(
                    key: const Key('board-search-more'),
                    onPressed: () => unawaited(_load(reset: false)),
                    child: const Text('פרסומים קודמים'),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
