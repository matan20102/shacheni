import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/address_catalog.dart';
import 'package:shacheni_app/features/building/address_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = AddressCatalog({
    'רמת גן': ['הגפן', 'הרצל'],
    'תל אביב -יפו': ['הרצל'],
  });
  test('address search combines street and city, normalizing punctuation', () {
    expect(catalog.search('גפן רמת גן').single.label, 'הגפן, רמת גן');
    expect(catalog.search('הרצל תל אביב יפו').single.city, 'תל אביב -יפו');
    expect(catalog.search('כתובת לא קיימת'), isEmpty);
    expect(catalog.search('א'), isEmpty);
  });
  test(
    'bundled government catalog contains real city and street suggestions',
    () async {
      final index = await AddressCatalog.load();
      expect(index.streets.length, greaterThan(1200));
      expect(index.search('הרצל רמת גן').first.label, 'הרצל, רמת גן');
      expect(index.search('הגננת ירושלים').first.label, 'הגננת, ירושלים');
    },
  );
  testWidgets(
    'selecting a street asks for a house number; manual entry stays available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final form = GlobalKey<FormState>();
      var address = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Form(
                key: form,
                child: AddressPicker(
                  catalog: catalog,
                  onChanged: (value) => address = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('building-address')),
        'גפן רמת',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('הגפן'));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byKey(const Key('building-house-number')),
        '18א',
      );
      await tester.pumpAndSettle();
      expect(address, 'הגפן 18א, רמת גן');
      expect(form.currentState!.validate(), isTrue);
      await tester.enterText(
        find.byKey(const Key('building-address')),
        'רחוב חדש, רמת גן',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('building-house-number')), findsOneWidget);
      expect(form.currentState!.validate(), isFalse);
      await tester.enterText(
        find.byKey(const Key('building-house-number')),
        '8',
      );
      expect(address, 'רחוב חדש 8, רמת גן');
      expect(form.currentState!.validate(), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
