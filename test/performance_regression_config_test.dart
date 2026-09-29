import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('performance safeguards', () {
    final osm = File('lib/services/osm_search_service.dart').readAsStringSync();
    final usage = File('lib/services/usage_meter.dart').readAsStringSync();
    final select = File('lib/pages/select_prospects_page.dart').readAsStringSync();
    final firestore = File('lib/services/firestore_service.dart').readAsStringSync();

    test('OSM search keeps fallbacks while adding bounded caches', () {
      expect(osm, contains('overpass.private.coffee'));
      expect(osm, contains('overpass-api.de'));
      expect(osm, contains('maps.mail.ru/osm/tools/overpass'));
      expect(osm, contains('_nearbyTtl'));
      expect(osm, contains('_maxNearbyCacheEntries'));
      expect(osm, contains('_endpointCooldown'));
      expect(osm, contains('_nearbyInFlight'));
    });

    test('premium sync is shared and deduplicated', () {
      expect(usage, contains('factory UsageMeter() => _instance'));
      expect(usage, contains('_cloudSyncMinInterval'));
      expect(usage, contains('_syncInFlight'));
      expect(usage, contains('forceRefresh'));
    });

    test('prospect search ignores stale async responses', () {
      expect(select, contains('token != _fetchToken'));
      expect(select, contains('final resultIds = nextOptions.map((p) => p.id).toSet()'));
      expect(select, contains('animate: !_loading'));
    });

    test('Firestore batches prospect reads with bounded concurrency', () {
      expect(firestore, contains('offset += 3'));
      expect(firestore, contains('Future.wait'));
      expect(firestore, contains('final order = <String, int>'));
    });
  });
}
