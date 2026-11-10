import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final prospection = File('lib/pages/select_prospects_page.dart').readAsStringSync();
  final itinerary = File('lib/pages/map_page.dart').readAsStringSync();

  test('the selection of customers is step four, after activity and radius', () {
    expect(prospection, contains('step: 4,'));
    expect(prospection, contains("? 'Sélectionner les clients'"));
    expect(prospection, contains('step: 3,'));
  });

  test('discovered results and checked customers have distinct labels', () {
    expect(prospection, contains(r"'$total résultat"));
    expect(prospection, contains(r"'$count coché"));
    expect(prospection, isNot(contains(r"'$chosen / $total'")));
    expect(prospection, isNot(contains(r"'$count/$limit'")));
    expect(prospection, isNot(contains('limit: limit, dirty: _dirty')));
  });

  test('the free plan limit continues to be checked', () {
    expect(prospection, contains('UsageMeter.defaultFreeMaxProspectsPerTour'));
    expect(prospection, contains('final nextCount ='));
  });

  test('only the stats show the itinerary count, the footer navigates', () {
    expect(itinerary, contains("label: 'Arrêts'"));
    expect(itinerary, isNot(contains("Itinéraire (")));
    expect(itinerary, contains('key: _stopsSectionKey'));
    expect(itinerary, contains('Scrollable.ensureVisible('));
    expect(itinerary, contains('onTap: _route.isEmpty ? null : _showStops'));
    expect(itinerary, contains("? 'Voir la liste' : 'View stops'"));
  });
}
