import 'package:flutter_test/flutter_test.dart';

import 'package:ai_prospect_gps/models/prospect.dart';
import 'package:ai_prospect_gps/services/french_registry_service.dart';
import 'package:ai_prospect_gps/services/prospect_search_config_service.dart';

void main() {
  group('Recherche gratuite par NAF/APE', () {
    test('restaurant et coiffure utilisent les bonnes familles NAF', () {
      expect(FrenchRegistryService.nafCodesFor('restaurant'),
          '56.10A,56.10B,56.10C');
      expect(FrenchRegistryService.nafCodesFor('coiffeur'), '96.02A');
      expect(FrenchRegistryService.nafCodesFor('barber'), '96.02A');
      expect(FrenchRegistryService.nafCodesFor('CHR'),
          '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z');
      expect(FrenchRegistryService.nafCodesFor('GMS'), '47.11D,47.11F');
      expect(FrenchRegistryService.nafCodesFor('CHR, GMS'),
          '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z,47.11D,47.11F');
      expect(FrenchRegistryService.nafCodesFor('parapharmacie'),
          '47.75Z,47.73Z');
      expect(FrenchRegistryService.nafCodesFor('grands comptes'), '');
      expect(FrenchRegistryService.nafCodesFor('zone d’activités'), '');
      expect(FrenchRegistryService.nafCodesFor('logistique'),
          '49.41A,49.41B,52.10B,52.29B');
      expect(FrenchRegistryService.nafCodesFor('56.10C'), '56.10C');
      expect(FrenchRegistryService.nafCodesFor('B2B'), isNull);
    });

    test('la recherche geographique respecte le rayon en kilometres', () {
      final uri = FrenchRegistryService.buildUri(
        lat: 43.296482,
        lng: 5.369780,
        radiusMeters: 2000,
        nafCodes: '56.10A',
      );
      expect(uri.host, 'recherche-entreprises.api.gouv.fr');
      expect(uri.path, '/near_point');
      expect(uri.queryParameters['radius'], '2.00');
      expect(uri.queryParameters['activite_principale'], '56.10A');
    });

    test('le registre francais ne remplace pas OSM hors de France', () {
      expect(FrenchRegistryService.supportsLocation(43.30, 5.37), isTrue);
      expect(FrenchRegistryService.supportsLocation(51.50, -0.13), isFalse);
    });
  });

  test('les options globales ont des valeurs sures en cas de panne', () {
    final config = ProspectSearchConfig.fromMap({});
    expect(config.overpassEnabled, isTrue);
    expect(config.registryEnabled, isTrue);
    expect(config.expandedRestaurants, isTrue);
    expect(config.copyWith(registryEnabled: false).registryEnabled, isFalse);
  });

  test('le tri grands comptes est explicite sans inventer de taille', () {
    final uri = FrenchRegistryService.buildUri(
      lat: 43.3, lng: 5.37, radiusMeters: 10000,
      nafCodes: '', sortBySize: true,
    );
    expect(uri.queryParameters['radius'], '10.00');
    expect(uri.queryParameters['sort_by_size'], 'true');
  });

  test('les metadonnees de prospection sont conservees', () {
    final p = Prospect(
      id: 'test', name: 'Restaurant test', address: 'Marseille',
      category: 'Restauration', lat: 43.29, lng: 5.37,
      source: 'Annuaire des Entreprises', siret: '12345678901234',
      nafCode: '56.10A',
    );
    expect(p.toJson()['siret'], '12345678901234');
    expect(p.copyWith(nafCode: '56.10C').toJson()['nafCode'], '56.10C');
  });
}
