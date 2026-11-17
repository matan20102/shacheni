part of 'building_app.dart';

// Board tab: the timeline, post cards, composing, conversations and reports.
extension _BoardTab on _BuildingExperienceState {
  Widget _board() {
    final posts = vm.posts;
    final pinned = posts.where((p) => p.pinned).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('השיחה של הבניין'),
                    const SizedBox(height: 4),
                    Text(
                      'לוח הבניין',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('board-search'),
                onPressed: vm.active == null ? null : _search,
                tooltip: 'חיפוש ופרסומים קודמים',
                icon: const Icon(Icons.search_rounded),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                key: const Key('board-new-post'),
                onPressed: vm.active == null ? null : _compose,
                tooltip: 'פרסום חדש',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        if (pinned.isNotEmpty) _pinnedBanner(pinned),
        Expanded(
          child: posts.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _empty(
                      'עוד אין כאן פרסומים',
                      'יש משהו לשתף עם השכנים?',
                      vm.active == null ? _chooseBuilding : _compose,
                    ),
                  ],
                )
              : BoardTimeline(
                  key: timelineKey,
                  buildingId: vm.active!.id,
                  posts: posts.reversed.toList(),
                  readStore: vm.readStore,
                  itemBuilder: _postCard,
                  leading: vm.canLoadOlder ? _loadOlderButton() : null,
                ),
        ),
      ],
    );
  }

  Widget _loadOlderButton() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Center(
      child: vm.loadingOlder
          ? const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : TextButton.icon(
              key: const Key('board-load-older'),
              onPressed: () async {
                try {
                  await vm.loadOlder();
                } catch (_) {
                  if (mounted) {
                    _message('לא הצלחנו לטעון פרסומים קודמים. נסו שוב.');
                  }
                }
              },
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('טעינת פרסומים קודמים'),
            ),
    ),
  );

  Widget _pinnedBanner(List<BoardPost> pinned) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
    child: InkWell(
      onTap: () => _conversation(pinned.first.id),
      borderRadius: BorderRadius.circular(12),
      child: GlassPanel(
        radius: 12,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            const Icon(Icons.push_pin_outlined, size: 15, color: glassTeal),
            const SizedBox(width: 6),
            Text(
              pinned.length == 1 ? 'נעוץ' : '${pinned.length} נעוצים',
              style: const TextStyle(fontSize: 11, color: glassTeal),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pinned.first.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _postCard(BoardPost post) => Align(
    key: Key('board-post-${post.id}'),
    alignment: post.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: .96,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: GlassPanel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          tint: post.mine ? const Color(0xFFD8F0ED) : Colors.white,
          opacity: post.closed ? .65 : .88,
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: post.mine
                        ? glassTeal
                        : const Color(0xFFE0E8F0),
                    foregroundColor: post.mine ? Colors.white : glassInk,
                    child: Text(
                      post.author.isEmpty ? 'ש' : post.author.characters.first,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'דירה ${post.apartment.split(' · כניסה ').first} · ${post.kind == PostKind.request ? 'בקשת עזרה' : 'מודעה'} · ${_relative(post.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: glassMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.pinned)
                    const Icon(
                      Icons.push_pin_outlined,
                      size: 14,
                      color: glassTeal,
                    ),
                  PostPhotos(paths: post.images, load: vm.repository.postImage),
                  if (post.closed)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 15,
                        color: glassTeal,
                      ),
                    ),
                  _postOptions(post),
                ],
              ),
              InkWell(
                onTap: () => _conversation(post.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    post.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ),
              if (post.closed)
                Text(
                  post.kind == PostKind.request ? 'נפתר' : 'לא רלוונטי',
                  style: const TextStyle(fontSize: 10, color: glassMuted),
                ),
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final reaction in post.reactions.entries)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: post.myReactions.contains(reaction.key)
                          ? const Color(0xFFB7DED7)
                          : Colors.white.withValues(alpha: .6),
                      side: BorderSide.none,
                      label: Text(
                        '${reaction.key} ${reaction.value}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: vm.busy
                          ? null
                          : () => _perform(
                              () => vm.repository.react(post.id, reaction.key),
                            ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'הוספת תגובה באימוג׳י',
                    icon: const Icon(
                      Icons.add_reaction_outlined,
                      size: 18,
                      color: glassMuted,
                    ),
                    constraints: const BoxConstraints(minWidth: 80),
                    padding: EdgeInsets.zero,
                    onSelected: (emoji) =>
                        _perform(() => vm.repository.react(post.id, emoji)),
                    itemBuilder: (_) => [
                      for (final emoji in ['💚', '🙌', '😊'])
                        PopupMenuItem(value: emoji, child: Text(emoji)),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _conversation(post.id),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                    ),
                    label: Text(
                      _replyCount(post.replies.length),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _postOptions(BoardPost post) => PopupMenuButton<String>(
    tooltip: 'אפשרויות פרסום',
    iconSize: 18,
    padding: EdgeInsets.zero,
    onSelected: (value) => _postAction(value, post),
    itemBuilder: (_) => [
      if (post.mine) ...[
        const PopupMenuItem(value: 'edit', child: Text('עריכת פרסום')),
        PopupMenuItem(
          value: 'close',
          child: Text(
            post.closed
                ? 'פתיחה מחדש'
                : post.kind == PostKind.request
                ? 'סימון כנפתר'
                : 'לא רלוונטי יותר',
          ),
        ),
      ],
      if (vm.active?.isAdmin ?? false)
        PopupMenuItem(
          value: 'pin',
          child: Text(post.pinned ? 'ביטול נעיצה' : 'נעיצה בלוח'),
        ),
      if (post.mine || (vm.active?.isAdmin ?? false))
        const PopupMenuItem(value: 'delete', child: Text('מחיקת פרסום')),
      if (!post.mine)
        const PopupMenuItem(value: 'report', child: Text('דיווח והסתרה')),
    ],
  );

  void _compose({BoardPost? post}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final home = vm.active;
    if (home == null) {
      _chooseBuilding();
      return;
    }
    _sheet(
      (ctx) => _PostForm(
        post: post,
        onSave: (text, kind, images) async {
          await vm.run(
            () => post != null
                ? vm.repository.edit(post.id, text)
                : images.isEmpty
                ? vm.repository.publish(home, text, kind)
                : vm.repository.publishWithImages(home, text, kind, images),
          );
          if (!ctx.mounted || !mounted) return;
          Navigator.pop(ctx);
          if (post == null) timelineKey.currentState?.showLatest();
        },
      ),
    );
  }

  void _conversation(String id) =>
      _sheet((ctx) => _Conversation(vm: vm, postId: id));

  Future<void> _postAction(String action, BoardPost post) async {
    switch (action) {
      case 'edit':
        _compose(post: post);
      case 'close':
        await _perform(() => vm.repository.close(post.id));
      case 'pin':
        await _perform(() => vm.repository.pin(post.id, vm.active!));
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('למחוק את הפרסום?'),
            content: const Text('גם התגובות לפרסום יימחקו.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('להשאיר'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('למחוק'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _perform(() => vm.repository.remove(post.id, vm.active!));
        }
      case 'report':
        await _report(post.id);
    }
  }

  void _search() {
    final home = vm.active;
    if (home == null) return;
    _sheet(
      (ctx) => BoardSearch(repository: vm.repository, buildingId: home.id),
    );
  }

  /// Reports a post or reply to the building managers and hides it here.
  Future<void> _report(String postId, {String? replyId}) async {
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('לדווח למנהלי הבניין?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'התוכן יוסתר אצלך, ומנהלי הבניין יחליטו אם להסיר אותו. הכותב לא יראה מי דיווח.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('report-reason'),
              maxLength: 300,
              maxLines: 2,
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(
                labelText: 'מה הבעיה? (לא חובה)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            key: const Key('report-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('דיווח והסתרה'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final sent = await _perform(
      () => vm.repository.report(postId, replyId: replyId, reason: reason),
    );
    if (sent && mounted) _message('הדיווח נשלח למנהלי הבניין.');
  }
}

class _PostForm extends StatefulWidget {
  const _PostForm({this.post, required this.onSave});
  final BoardPost? post;
  final Future<void> Function(String, PostKind, List<PostImage>) onSave;
  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> with _AsyncForm<_PostForm> {
  late final text = TextEditingController(text: widget.post?.text ?? '');
  late PostKind kind = widget.post?.kind ?? PostKind.notice;
  List<PostImage> images = const [];
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('רק לשכנים בבניין שלך'),
          const SizedBox(height: 8),
          Text(
            widget.post == null ? 'מה תרצה לשתף?' : 'עריכת הפרסום',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          if (widget.post == null)
            SegmentedButton<PostKind>(
              segments: const [
                ButtonSegment(
                  value: PostKind.notice,
                  label: Text('מודעה'),
                  icon: Icon(Icons.campaign_outlined),
                ),
                ButtonSegment(
                  value: PostKind.request,
                  label: Text('בקשת עזרה'),
                  icon: Icon(Icons.waving_hand_outlined),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.first),
            ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('board-post-text'),
            controller: text,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: kind == PostKind.request
                  ? 'איזו עזרה תשמח לקבל?'
                  : 'עדכון קטן, שאלה או משהו טוב שקרה…',
            ),
            validator: (v) => (v?.trim().isEmpty ?? true)
                ? 'יש לכתוב משהו לפני הפרסום'
                : null,
          ),
          if (widget.post == null) ...[
            const SizedBox(height: 8),
            PostImagePicker(
              images: images,
              enabled: !submitting,
              onChanged: (next) => setState(() => images = next),
            ),
          ],
          const SizedBox(height: 20),
          if (submitError != null)
            Text(submitError!, style: const TextStyle(color: glassError)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('board-post-submit'),
              onPressed: submitting
                  ? null
                  : () {
                      if (form.currentState!.validate()) {
                        submit(
                          () => widget.onSave(text.text.trim(), kind, images),
                        );
                      }
                    },
              child: Text(widget.post == null ? 'פרסום בלוח' : 'שמירת השינוי'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Conversation extends StatefulWidget {
  const _Conversation({required this.vm, required this.postId});
  final BuildingViewModel vm;
  final String postId;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation>
    with _AsyncForm<_Conversation> {
  final reply = TextEditingController();
  @override
  void dispose() {
    reply.dispose();
    super.dispose();
  }

  Widget _replyMenu(BoardReply r, BoardPost post) {
    final admin = widget.vm.active?.isAdmin ?? false;
    return PopupMenuButton<String>(
      key: ValueKey('reply-menu-${r.id}'),
      tooltip: 'אפשרויות תגובה',
      iconSize: 18,
      padding: EdgeInsets.zero,
      enabled: !submitting,
      onSelected: (value) => _replyAction(value, r, post),
      itemBuilder: (_) => [
        if (r.mine)
          const PopupMenuItem(value: 'edit', child: Text('עריכת תגובה')),
        if (r.mine || admin)
          const PopupMenuItem(value: 'delete', child: Text('מחיקת תגובה')),
        if (!r.mine)
          const PopupMenuItem(value: 'report', child: Text('דיווח והסתרה')),
      ],
    );
  }

  Future<void> _replyAction(String action, BoardReply r, BoardPost post) async {
    final repository = widget.vm.repository;
    switch (action) {
      case 'edit':
        var text = r.text;
        final saved = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('עריכת תגובה'),
            content: TextFormField(
              key: const Key('reply-edit-text'),
              initialValue: r.text,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (value) => text = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('ביטול'),
              ),
              FilledButton(
                key: const Key('reply-edit-save'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('שמירה'),
              ),
            ],
          ),
        );
        if (saved != true || !mounted || text.trim().isEmpty) return;
        await submit(
          () => widget.vm.run(() => repository.editReply(r.id, text)),
        );
      case 'delete':
        await submit(() => widget.vm.run(() => repository.removeReply(r.id)));
      case 'report':
        await submit(
          () => widget.vm.run(() => repository.report(post.id, replyId: r.id)),
        );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vm,
    builder: (context, _) {
      final post = widget.vm.posts
          .where((p) => p.id == widget.postId)
          .firstOrNull;
      if (post == null) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text('הפרסום אינו זמין בבניין הנוכחי.'),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 260;
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, compact ? 8 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'השיחה על הפרסום',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'סגירת שיחה',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: ListView(
                      children: [
                        GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.author,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(post.text),
                              PostPhotos(
                                paths: post.images,
                                load: widget.vm.repository.postImage,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (post.replies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'עוד אין תגובות. אפשר להתחיל את השיחה.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        for (final r in post.replies)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassPanel(
                              padding: const EdgeInsets.all(16),
                              tint: r.mine
                                  ? const Color(0xFFD8F0ED)
                                  : Colors.white,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.mine ? 'אני' : r.author,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: glassTeal,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (r.edited)
                                        const Text(
                                          'נערך',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: glassMuted,
                                          ),
                                        ),
                                      if (r.id.isNotEmpty) _replyMenu(r, post),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(r.text),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  if (submitError != null)
                    Text(
                      submitError!,
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: const TextStyle(color: glassError),
                    ),
                  if (post.closed)
                    const Text(
                      'הפרסום סגור לתגובות. הכותב יכול לפתוח אותו מחדש.',
                      style: TextStyle(color: glassMuted),
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: reply,
                            minLines: 1,
                            maxLines: compact ? 1 : 3,
                            maxLength: 1000,
                            decoration: const InputDecoration(
                              hintText: 'כותבים לשכנים…',
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'שליחת תגובה',
                          onPressed: submitting || reply.text.trim().isEmpty
                              ? null
                              : () => submit(() async {
                                  await widget.vm.run(
                                    () => widget.vm.repository.reply(
                                      post.id,
                                      reply.text,
                                    ),
                                  );
                                  if (!mounted) return;
                                  reply.clear();
                                  setState(() {});
                                }),
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        if (compact)
                          IconButton(
                            tooltip: 'סגירת שיחה',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
