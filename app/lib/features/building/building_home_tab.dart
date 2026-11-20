part of 'building_app.dart';

// Home tab: greeting, quick actions and the building summary.
extension _HomeTab on _BuildingExperienceState {
  Widget _home() {
    final posts = vm.posts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: [
        const Eyebrow('טוב להיות בבית'),
        const SizedBox(height: Space.s),
        Text(
          'שלום, ${vm.repository.profile.firstName.isEmpty ? 'שכן' : vm.repository.profile.firstName} 👋',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: Space.s),
        Text(
          'הדברים הקטנים שמחברים את הבניין.',
          style: TextStyle(color: context.glass.muted, fontSize: 15),
        ),
        const SizedBox(height: Space.xxl),
        GlassPanel(
          tone: GlassTone.accent,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('הבית שלי'),
                    const SizedBox(height: Space.s),
                    Text(
                      vm.active == null
                          ? 'מתחילים עם הבניין שלך'
                          : vm.active!.householdName.isNotEmpty
                          ? vm.active!.householdName
                          : _apartmentLabel(vm.active!),
                      style: Theme.of(context).textTheme.headlineMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.s),
                    Text(
                      vm.active == null
                          ? 'אפשר ליצור בניין או להצטרף עם קוד.'
                          : vm.active!.householdName.isEmpty
                          ? vm.active!.name
                          : '${vm.active!.name} · ${_apartmentLabel(vm.active!)}',
                      style: TextStyle(color: context.glass.muted),
                    ),
                    const SizedBox(height: Space.m),
                    SoftTag(
                      vm.live ? 'הבית שלך' : 'נתוני הדגמה',
                      icon: vm.live
                          ? Icons.check_circle_outline
                          : Icons.science_outlined,
                    ),
                    if (vm.active?.isApartmentAdmin ?? false)
                      TextButton.icon(
                        key: const Key('household-edit'),
                        onPressed: _editHousehold,
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: Text(
                          vm.active!.householdName.isEmpty
                              ? 'לתת שם לבית'
                              : 'עריכת שם הבית',
                        ),
                      ),
                  ],
                ),
              ),
              const BuildingMark(size: 78),
            ],
          ),
        ),
        const SectionTitle('מה עושים היום?'),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: (c.maxWidth - 12) / 2,
                child: _ActionCard(
                  Icons.edit_note_rounded,
                  vm.active == null ? 'יצירת בניין' : 'לפרסם בלוח',
                  vm.active == null ? 'מתחילים בית חדש' : 'עדכון או בקשת עזרה',
                  () {
                    if (vm.active == null) {
                      _create();
                      return;
                    }
                    _navigate(1);
                    _compose();
                  },
                ),
              ),
              SizedBox(
                width: (c.maxWidth - 12) / 2,
                child: _ActionCard(
                  vm.active == null
                      ? Icons.add_home_outlined
                      : Icons.forum_outlined,
                  vm.active == null ? 'הצטרפות לבניין' : 'לוח הבניין',
                  vm.active == null ? 'עם הקוד שקיבלת' : 'מה חדש אצל השכנים',
                  vm.active == null ? () => _join() : () => _navigate(1),
                ),
              ),
            ],
          ),
        ),
        SectionTitle(
          'מה חדש בבניין',
          action: TextButton(
            onPressed: () => _navigate(1),
            child: const Text('לכל הפרסומים'),
          ),
        ),
        if (posts.isEmpty)
          _empty(
            'הלוח שלכם מתחיל כאן',
            'עדכון ראשון הוא דרך טובה להגיד שלום.',
            _compose,
          )
        else
          for (final post in posts.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _conversation(post.id),
                borderRadius: BorderRadius.circular(26),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (post.pinned)
                            const SoftTag(
                              'נעוץ',
                              icon: Icons.push_pin_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        post.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${_replyCount(post.replies.length)} · לפתיחת השיחה',
                        style: TextStyle(
                          color: context.glass.accent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SectionTitle('נעים להכיר'),
        const GlassPanel(
          child: _FeatureLine(
            Icons.waving_hand_outlined,
            'השכנים, קרוב מתמיד',
            'פניות פרטיות לדירה יתווספו בהמשך.\nהתוכן שלהן יהיה גלוי רק למשתתפים.',
          ),
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.icon, this.title, this.description);
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.glass.accent.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: context.glass.accent, size: 24),
      ),
      const SizedBox(width: Space.l),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.xs),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: context.glass.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Corners.panel),
      child: GlassPanel(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.glass.accent, size: 28),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Space.xs),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: context.glass.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
