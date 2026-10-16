import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/app/app.dart';

void main() {
  testWidgets('unconfigured app starts the current Hebrew building preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const NayborApp());
    await tester.pumpAndSettle();

    expect(find.text('נייבור'), findsWidgets);
    expect(find.text('בית אחד.\nהרבה שכנים טובים.'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
  });
}
