import 'dart:convert';

import 'package:flutter/services.dart';

class AddressCatalog {
  AddressCatalog(this.streets);
  final Map<String, List<String>> streets;
  late final _choices = [
    for (final city in streets.entries)
      for (final street in city.value) AddressChoice(city.key, street),
  ];
  static Future<AddressCatalog>? _loaded;
  static AddressCatalog? _cached;
  static AddressCatalog? get cached => _cached;
  static Future<AddressCatalog> load() => _loaded ??= _read();
  static Future<AddressCatalog> _read() async {
    final value = jsonDecode(
      await rootBundle.loadString('assets/addresses/israel_streets.json'),
    ) as Map<String, dynamic>;
    return _cached = AddressCatalog({
      for (final entry in (value['cities'] as Map<String, dynamic>).entries)
        entry.key: (entry.value as List).cast<String>(),
    });
  }

  static String _normalize(String value) => value
      .replaceAll(RegExp('[־–—-]'), ' ')
      .replaceAll(RegExp('[״"׳\u0027]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Iterable<AddressChoice> search(String query) {
    final text = _normalize(query);
    if (text.length < 2) return const [];
    final words = text.split(' ');
    final result = <AddressChoice>[];
    for (final choice in _choices) {
      if (words.every(choice.searchText.contains)) result.add(choice);
      if (result.length == 12) break;
    }
    return result;
  }
}

class AddressChoice {
  AddressChoice(this.city, this.street);
  final String city, street;
  String get label => '$street, $city';
  late final searchText = AddressCatalog._normalize('$street $city');
}
