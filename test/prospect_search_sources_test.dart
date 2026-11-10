import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/models/prospect.dart';
import 'package:ai_prospect_gps/services/french_registry_service.dart';
import 'package:ai_prospect_gps/services/prospect_search_config_service.dart';

void main() {
  test('codes NAF disponibles pour CHR GMS coiffeur parapharmacie', () {
    expect(FrenchRegistryService.nafCodesFor('restaurant'), '56.10A,56.10B,56.10C');
    expect(FrenchRegistryService.nafCodesFor('coiffeur'), '96.02A');
    expect(FrenchRegistryService.nafCodesFor('CHR'),
        '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z');
    expect(FrenchRegistryService.nafCodesFor('GMS'), '47.11D,47.11F');
    expect(FrenchRegistryService.nafCodesFor('CHR, GMS'),
        '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z,47.11D,47.11F');
    expect(FrenchRegistryService.nafCodesFor('parapharmacie'), '47.75Z,47.73Z');
    expect(FrenchRegistryService.nafCodesFor('zone d’activités'), '');
  });
  test('recherche 10 km officielle sans utiliser NAF a l etranger', () {
    final uri=FrenchRegistryService.buildUri(lat:43.2964,lng:5.3698,
        radiusMeters:10000,nafCodes:'56.10A');
    expect(uri.path, '/near_point');
    expect(uri.queryParameters['radius'],'10.00');
    expect(FrenchRegistryService.supportsLocation(43.3,5.37),true);
    expect(FrenchRegistryService.supportsLocation(51.5,-0.13),false);
  });
  test('config par defaut sans fonctions serveur deployees', () {
    final config=ProspectSearchConfig.fromMap({});
    expect(config.overpassEnabled,true);
    expect(config.registryEnabled,true);
    expect(config.expandedRestaurants,true);
  });
  test('donnees legales preservees lors sauvegarde prospects', () {
    final p=Prospect(id:'test',name:'CHR',address:'Marseille',category:'CHR',
        lat:43.3,lng:5.37,source:'Annuaire des Entreprises',
        siret:'12345678901234',nafCode:'56.10A');
    expect(p.toJson()['siret'],'12345678901234');
  });
}
