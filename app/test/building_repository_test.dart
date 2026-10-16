import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';

void main() {
  test('existing apartment needs both approvals in either order', () {
    for (final buildingFirst in [true, false]) {
      final repository = LocalBuildingRepository(seed: false);
      final home = repository.resolveCode('neighbor')!;
      final application = repository.apply(home, '12');
      expect(application.apartmentHasAdmin, isTrue);
      repository.approve(application.id, byBuildingAdmin: buildingFirst);
      expect(repository.homes, isEmpty);
      expect(repository.posts(home.id), isEmpty);
      repository.approve(application.id, byBuildingAdmin: !buildingFirst);
      expect(repository.homes.single.id, home.id);
      expect(repository.homes.single.isApartmentAdmin, isFalse);
      // Repeated approval must not create another membership.
      repository.approve(application.id, byBuildingAdmin: true);
      expect(repository.homes, hasLength(1));
    }
  });

  test('new apartment gets its first admin after building approval', () {
    final repository = LocalBuildingRepository(seed: false);
    final application = repository.apply(
      repository.resolveCode('NEIGHBOR')!,
      '999',
    );
    expect(application.apartmentHasAdmin, isFalse);
    repository.approve(application.id, byBuildingAdmin: true);
    expect(repository.homes.single.apartment, '999');
    expect(repository.homes.single.isApartmentAdmin, isTrue);
    expect(repository.homes.single.isAdmin, isFalse);
    expect(repository.homes.single.isCommittee, isFalse);
  });

  test(
    'building creation gives separate roles and needs no apartment roster',
    () {
      final repository = LocalBuildingRepository(seed: false);
      final home = repository.createBuilding('הבניין שלנו', 'הגפן 3', '12', 2);
      expect(home.isAdmin && home.isCommittee && home.isApartmentAdmin, isTrue);
      expect(repository.posts(home.id), isEmpty);
      expect(repository.resolveCode(home.code), home);
    },
  );

  test('switching buildings isolates board state and pending requests are inaccessible', () {
    final repository = LocalBuildingRepository();
    final vm = BuildingViewModel(repository);
    addTearDown(vm.dispose);
    expect(vm.posts, isNotEmpty);
    vm.select('olive');
    expect(vm.posts, isEmpty);
    vm.run(
      () => vm.repository.publish(vm.active!, 'רק לבית הזית', PostKind.notice),
    );
    expect(vm.posts.single.text, 'רק לבית הזית');
    vm.select('garden');
    expect(vm.posts.any((p) => p.text == 'רק לבית הזית'), isFalse);
    final application = repository.apply(
      repository.resolveCode('NEIGHBOR')!,
      '12',
    );
    expect(vm.select(application.building.id), throwsStateError);
    expect(
      () =>
          vm.repository.publish(application.building, 'אסור', PostKind.notice),
      throwsStateError,
    );
  });

  test('author can resolve, reopen and edit; closed posts reject replies', () {
    final repository = LocalBuildingRepository(seed: false);
    final home = repository.createBuilding('בית', 'כתובת', '1', 1);
    repository.publish(home, 'צריך עזרה', PostKind.request);
    final id = repository.posts(home.id).single.id;
    repository.reply(id, 'בשמחה');
    repository.close(id);
    expect(() => repository.reply(id, 'עוד תגובה'), throwsStateError);
    repository.close(id);
    repository.edit(id, 'כבר הסתדרתי');
    repository.reply(id, 'מעולה');
    final post = repository.posts(home.id).single;
    expect(post.text, 'כבר הסתדרתי');
    expect(post.replies, hasLength(2));
  });

  test(
    'emoji toggles count; non-author cannot edit or close neighbor posts',
    () {
      final repository = LocalBuildingRepository();
      repository.react('help', '🙌');
      expect(
        repository
            .posts('garden')
            .firstWhere((p) => p.id == 'help')
            .reactions['🙌'],
        3,
      );
      repository.react('help', '🙌');
      expect(
        repository
            .posts('garden')
            .firstWhere((p) => p.id == 'help')
            .reactions['🙌'],
        2,
      );
      expect(() => repository.edit('help', 'שינוי'), throwsStateError);
      expect(() => repository.close('help'), throwsStateError);
      expect(
        () => repository.pin('help', repository.homes.last),
        throwsStateError,
      );
    },
  );
}
