import 'package:flutter_test/flutter_test.dart';
import 'package:shacheni_app/data/building/building_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a declined applicant is told when to ask again', () {
    expect(
      buildingErrorMessage(const PostgrestException(message: 'TRY_LATER')),
      contains('24 שעות'),
    );
  });
}
