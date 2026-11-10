import 'dart:convert';

import 'package:ai_prospect_gps/services/french_registry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Shape and representative branch fields from the public near_point response
// captured on 2026-10-29 in work/mobile-real-inputs/chr.json. No network in tests.
Map<String, Object?> branch({String siret = '44533010300026'}) => {
  'activite_principale': '56.10C',
  'adresse': "26 AVENUE DE L'OPERA 75001 PARIS",
  'code_postal': '75001',
  'commune': '75101',
  'etat_administratif': 'A',
  'latitude': '48.867078972',
  'longitude': '2.3340682345',
  'liste_enseignes': null,
  'nom_commercial': null,
  'siret': siret,
  'statut_diffusion_etablissement': 'O',
};

Map<String, Object?> company(List<Map<String, Object?>> branches) => {
  'nom_complet': 'CAFE SIRENE FRANCE (STARBUCKS COFFEE)',
  'etat_administratif': 'A',
  'statut_diffusion': 'O',
  'activite_principale': '56.10C',
  'siege': {
    ...branch(siret: '44533010399999'),
    'adresse': 'SIEGE DISTANT, LYON',
    'latitude': '45.75',
    'longitude': '4.85',
  },
  'matching_etablissements': branches,
};

http.Response response(List<Map<String, Object?>> companies) => http.Response(
  jsonEncode({'results': companies, 'total_pages': 1}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('restricted or unknown diffusion never creates a public prospect', () async {
    final client=MockClient((_) async => response([
      {...company([branch()]),'statut_diffusion':'P'},
      {...company([branch()]),'statut_diffusion':null},
      company([{...branch(),'statut_diffusion_etablissement':'P'}]),
      company([{...branch(),'statut_diffusion_etablissement':null}]),
    ]));
    addTearDown(client.close);
    final found=await FrenchRegistryService(client:client).searchNearby(
      lat:48.865,lng:2.333,radiusMeters:3000,query:'CHR');
    expect(found,isEmpty);
  });
  test('real latitude/longitude shape returns only active matching nearby branches', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/near_point');
      expect(request.url.queryParameters['radius'], '0.50');
      expect(request.url.queryParameters['activite_principale'], '56.10A,56.10B,56.10C');
      return response([
        company([
          branch(),
          {...branch(siret: '44533010300027'), 'etat_administratif': 'F'},
          {...branch(siret: '44533010300028'), 'etat_administratif': 'C'},
          {...branch(siret: '44533010300029'), 'etat_administratif': null},
          {...branch(siret: '44533010300030'), 'activite_principale': '68.20B'},
          {...branch(siret: '44533010300031'), 'activite_principale': null},
          {...branch(siret: '44533010300032'), 'latitude': '48.90'},
          branch(siret: 'invalid-siret'),
          {...branch(siret: '44533010300033'), 'date_fermeture': '2025-12-31'},
          {...branch(siret: '44533010300034'), 'latitude': 'NaN'},
        ]),
      ]);
    });
    final results = await FrenchRegistryService(client: client).searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    );
    expect(results, hasLength(1));
    expect(results.single.id, 'siret_44533010300026');
    expect(results.single.siret, '44533010300026');
    expect(results.single.nafCode, '56.10C');
    expect(results.single.lat, 48.867078972);
    expect(results.single.lng, 2.3340682345);
    expect(results.single.address, "26 AVENUE DE L'OPERA 75001 PARIS");
    expect(results.single.name, 'CAFE SIRENE FRANCE (STARBUCKS COFFEE)');
    expect(requests, 1);
  });

  test('numeric coordinates take precedence over the legacy coordinate string', () async {
    final service = FrenchRegistryService(client: MockClient((_) async => response([
      company([
        {
          ...branch(),
          'latitude': 48.867078972,
          'longitude': 2.3340682345,
          'coordonnees': '45.75,4.85',
        },
      ]),
    ])));
    final results = await service.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    );
    expect(results, hasLength(1));
    expect(results.single.lat, 48.867078972);
  });

  test('legacy coordonnees remain supported when separate coordinates are absent', () async {
    final service = FrenchRegistryService(client: MockClient((_) async => response([
      company([
        {
          ...branch(),
          'latitude': null,
          'longitude': null,
          'coordonnees': '48.867078972,2.3340682345',
        },
      ]),
    ])));
    final results = await service.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    );
    expect(results, hasLength(1));
    expect(results.single.lng, 2.3340682345);
  });

  test('address fallbacks use branch geography and never the distant head office', () async {
    final service = FrenchRegistryService(client: MockClient((_) async => response([
      company([
        {...branch(), 'adresse': '', 'geo_adresse': '26 avenue locale, Paris'},
        {
          ...branch(siret: '44533010300027'),
          'adresse': null,
          'geo_adresse': null,
          'numero_voie': '26',
          'type_voie': 'AVENUE',
          'libelle_voie': "DE L'OPERA",
          'libelle_commune': 'PARIS',
        },
        {...branch(siret: '44533010300028'), 'adresse': null, 'code_postal': null},
      ]),
    ])));
    final results = await service.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    );
    final byId = {for (final place in results) place.id: place};
    expect(byId['siret_44533010300026']!.address, '26 avenue locale, Paris');
    expect(byId['siret_44533010300027']!.address, "26 AVENUE DE L'OPERA, 75001 PARIS");
    expect(byId['siret_44533010300028']!.address, isEmpty);
    expect(results.every((place) => !place.address.contains('LYON')), isTrue);
  });

  test('head office is considered only when no matching branches are supplied', () async {
    final localHeadOffice = {...branch(), 'latitude': '48.865', 'longitude': '2.333'};
    final service = FrenchRegistryService(client: MockClient((_) async => response([
      {...company([]), 'siege': localHeadOffice},
    ])));
    expect(await service.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    ), hasLength(1));
  });

  test('successful empty official response is distinct from a failed network request', () async {
    final empty = FrenchRegistryService(client: MockClient((_) async => response([])));
    expect(await empty.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    ), isEmpty);
    final offline = FrenchRegistryService(client: MockClient((_) async {
      throw http.ClientException('offline');
    }));
    await expectLater(offline.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
    ), throwsA(isA<http.ClientException>()));
  });

  test('HTTP errors and invalid official responses stay visible as failures', () async {
    for (final result in [http.Response('unavailable', 503), http.Response('{}', 200)]) {
      final service = FrenchRegistryService(client: MockClient((_) async => result));
      await expectLater(service.searchNearby(
        lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'restaurant',
      ), throwsA(anyOf(isA<StateError>(), isA<FormatException>())));
    }
  });

  test('grossiste beverage and food mappings match the explicit local reference', () {
    expect(FrenchRegistryService.nafCodesFor('grossiste boissons'), '46.34Z');
    expect(FrenchRegistryService.nafCodesFor('négociant boissons'), '46.34Z');
    expect(FrenchRegistryService.nafCodesFor('grossiste alimentaire')!.split(','), [
      '46.31Z', '46.32A', '46.32B', '46.32C', '46.33Z', '46.36Z',
      '46.37Z', '46.38A', '46.38B', '46.39A', '46.39B',
    ]);
    expect(FrenchRegistryService.nafCodesFor('restaurant'), '56.10A,56.10B,56.10C');
  });

  test('unknown categories and foreign locations make no registry HTTP requests', () async {
    var requests = 0;
    final service = FrenchRegistryService(client: MockClient((_) async {
      requests++;
      return response([]);
    }));
    expect(await service.searchNearby(
      lat: 48.865, lng: 2.333, radiusMeters: 500, query: 'activité inconnue',
    ), isEmpty);
    expect(await service.searchNearby(
      lat: 51.5, lng: -0.13, radiusMeters: 500, query: 'restaurant',
    ), isEmpty);
    expect(requests, 0);
  });
}
