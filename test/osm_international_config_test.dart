import 'package:flutter_test/flutter_test.dart';

import 'package:ai_prospect_gps/services/osm_search_service.dart';

void main() {
  group('international geocoding configuration', () {
    test('United Kingdom address is not restricted to France', () {
      final uri = OSMSearchService.buildGeocodeUri(
        address: '10 Downing Street, London, United Kingdom',
        languageCode: 'en',
      );

      expect(uri.host, 'nominatim.openstreetmap.org');
      expect(uri.queryParameters['q'],
          '10 Downing Street, London, United Kingdom');
      expect(uri.queryParameters['accept-language'], 'en');
      expect(uri.queryParameters.containsKey('countrycodes'), isFalse);
    });

    test('United States address is not restricted to France', () {
      final uri = OSMSearchService.buildGeocodeUri(
        address: '1600 Pennsylvania Avenue NW, Washington, DC, USA',
        languageCode: 'en',
      );

      expect(uri.queryParameters['q'],
          '1600 Pennsylvania Avenue NW, Washington, DC, USA');
      expect(uri.queryParameters.containsKey('countrycodes'), isFalse);
    });

    test('French interface keeps French Nominatim labels without country lock', () {
      final uri = OSMSearchService.buildGeocodeUri(
        address: '10 rue de la Paix, Paris, France',
        languageCode: 'fr',
      );

      expect(uri.queryParameters['accept-language'], 'fr');
      expect(uri.queryParameters.containsKey('countrycodes'), isFalse);
    });
  });
}
