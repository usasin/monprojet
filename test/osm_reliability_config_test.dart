import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source =
      File('lib/services/osm_search_service.dart').readAsStringSync();

  test('prospect search has several Overpass fallbacks', () {
    expect(source, contains('overpass.private.coffee'));
    expect(source, contains('overpass-api.de'));
    expect(source, contains('maps.mail.ru/osm/tools/overpass'));
    expect(source, contains('_requestOverpass'));
  });

  test('international geocoding is not restricted to France', () {
    expect(source, isNot(contains("'countrycodes'")));
    expect(source, contains("'accept-language'"));
  });
}
