import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_repository.dart';
import 'package:shacheni_app/data/building/supabase_building_repository.dart';
import 'package:shacheni_app/features/building/post_images.dart';

// A 1×1 transparent PNG.
final pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  test('a post keeps its photos and they load back', () async {
    final repo = LocalBuildingRepository();
    final home = repo.homes.first;
    await repo.publishWithImages(home, 'מצאתי מפתחות', PostKind.notice, [
      PostImage(pixel, 'image/png'),
    ]);
    final post = repo.posts(home.id).firstWhere((p) => p.text == 'מצאתי מפתחות');
    expect(post.images, hasLength(1));
    expect(await repo.postImage(post.images.single), pixel);
  });

  test('more than four photos or other formats are refused', () async {
    final repo = LocalBuildingRepository();
    final home = repo.homes.first;
    expect(
      repo.publishWithImages(home, 'x', PostKind.notice, [
        for (var i = 0; i < 5; i++) PostImage(pixel, 'image/png'),
      ]),
      throwsArgumentError,
    );
    expect(
      repo.publishWithImages(home, 'x', PostKind.notice, [
        PostImage(pixel, 'image/gif'),
      ]),
      throwsArgumentError,
    );
  });

  test('the server post carries its image paths', () {
    final post = SupabaseBuildingRepository.postFromJson({
      'id': 'p',
      'building_id': 'b',
      'author': 'דנה',
      'apartment': '3',
      'text': 'שלום',
      'kind': 'notice',
      'created_at': '2026-11-17T10:00:00Z',
      'replies': <dynamic>[],
      'reactions': <String, dynamic>{},
      'my_reactions': <dynamic>[],
      'images': ['b/u/1.jpg', 'b/u/2.png'],
    });
    expect(post.images, ['b/u/1.jpg', 'b/u/2.png']);
    final older = SupabaseBuildingRepository.postFromJson({
      'id': 'p',
      'building_id': 'b',
      'author': 'דנה',
      'apartment': '3',
      'text': 'שלום',
      'kind': 'notice',
      'created_at': '2026-11-17T10:00:00Z',
      'replies': <dynamic>[],
      'reactions': <String, dynamic>{},
      'my_reactions': <dynamic>[],
    });
    expect(older.images, isEmpty);
  });

  testWidgets('photos show on the post and open full screen', (tester) async {
    final loaded = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: PostPhotos(
              paths: const ['a.png', 'b.png'],
              load: (path) async {
                loaded.add(path);
                return pixel;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loaded, ['a.png', 'b.png']);
    expect(find.byType(Image), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('post-photo-a.png')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-photo-close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-photo-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-photo-close')), findsNothing);
  });

  testWidgets('chosen photos can be removed before publishing', (tester) async {
    var images = [PostImage(pixel, 'image/png'), PostImage(pixel, 'image/png')];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PostImagePicker(
              images: images,
              onChanged: (next) => setState(() => images = next),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('post-image-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-image-remove-0')));
    await tester.pump();
    expect(images, hasLength(1));
    expect(find.byKey(const Key('post-image-1')), findsNothing);
  });
}
