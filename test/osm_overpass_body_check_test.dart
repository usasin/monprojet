import 'package:ai_prospect_gps/services/osm_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ok = '{"osm3s":{"timestamp_osm_base":"2999-01-01T00:00:00Z"},"elements":[]}';

  test('une réponse Overpass saine est acceptée', () {
    expect(OSMSearchService.checkOverpassBody(ok).status, OverpassBodyStatus.ok);
  });

  test('HTTP 200 avec timeout interne est refusé (miroir suivant)', () {
    const body =
        '{"remark":"runtime error: Query timed out in \\"query\\" at line 3 after 21 seconds.","elements":[]}';
    final check = OSMSearchService.checkOverpassBody(body);
    expect(check.status, OverpassBodyStatus.invalid);
    expect(check.message, contains('timeout'));
  });

  test('page HTML ou JSON incomplet est refusé', () {
    expect(OSMSearchService.checkOverpassBody('<html>busy</html>').status,
        OverpassBodyStatus.invalid);
    expect(OSMSearchService.checkOverpassBody('{"a":1}').status,
        OverpassBodyStatus.invalid);
  });

  test('un miroir aux données périmées est signalé', () {
    const body =
        '{"osm3s":{"timestamp_osm_base":"2026-06-01T00:00:00Z"},"elements":[]}';
    final check = OSMSearchService.checkOverpassBody(body,
        now: DateTime.utc(2026, 10, 27));
    expect(check.status, OverpassBodyStatus.stale);
  });
}
