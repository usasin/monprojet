import 'dart:async';

import 'package:ai_prospect_gps/services/directory_online_search.dart';
import 'package:ai_prospect_gps/services/osm_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

OSMPlace business({
  String id = 'osm:node:1',
  String name = 'Hôtel de Paris',
  double lat = 48.85,
  double lng = 2.35,
  String? phone,
  String? siret,
  String? nafCode,
}) =>
    OSMPlace(
      id: id,
      name: name,
      address: 'Paris',
      lat: lat,
      lng: lng,
      category: 'Hôtel',
      phone: phone,
      siret: siret,
      nafCode: nafCode,
    );

class Providers {
  int osmCalls = 0;
  int registryCalls = 0;
  List<OSMPlace> osmPlaces = [];
  List<OSMPlace> registryPlaces = [];
  Future<List<OSMPlace>> Function()? osmAction;
  Future<List<OSMPlace>> Function()? registryAction;
  Map<String, Object?>? osmArguments;
  Map<String, Object?>? registryArguments;

  Future<List<OSMPlace>> osm({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    required String languageCode,
  }) async {
    osmCalls++;
    osmArguments = {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'query': query,
      'languageCode': languageCode,
    };
    if (osmAction != null) return await osmAction!();
    return osmPlaces;
  }

  Future<List<OSMPlace>> registry({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
  }) async {
    registryCalls++;
    registryArguments = {
      'lat': lat,
      'lng': lng,
      'radiusMeters': radiusMeters,
      'query': query,
    };
    if (registryAction != null) return await registryAction!();
    return registryPlaces;
  }

  DirectoryOnlineSearch service(
          {Duration timeout = const Duration(seconds: 20)}) =>
      DirectoryOnlineSearch(
        osmSearch: osm,
        registrySearch: registry,
        timeout: timeout,
      );
}

void main() {
  test(
      'starts both eligible providers before awaiting either and forwards query',
      () async {
    final osm = Completer<List<OSMPlace>>();
    final registry = Completer<List<OSMPlace>>();
    final providers = Providers()
      ..osmAction = (() => osm.future)
      ..registryAction = (() => registry.future);
    final request = providers.service().search(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: 'hotel',
          languageCode: 'en',
        );
    expect(providers.osmCalls, 1);
    expect(providers.registryCalls, 1);
    expect(providers.osmArguments, {
      'lat': 48.85,
      'lng': 2.35,
      'radiusMeters': 1000,
      'query': 'hotel',
      'languageCode': 'en',
    });
    expect(providers.registryArguments, {
      'lat': 48.85,
      'lng': 2.35,
      'radiusMeters': 1000,
      'query': 'hotel',
    });
    osm.complete([business()]);
    registry.complete([]);
    expect(await request, hasLength(1));
  });

  test('two successful empty sources produce a real empty result', () async {
    final providers = Providers();
    final result = await providers.service().searchDetailed(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: '',
        );
    expect(result.places, isEmpty);
    expect(result.partial, isFalse);
    expect(result.failedSources, isEmpty);
    expect(providers.osmCalls, 1);
    expect(providers.registryCalls, 1);
  });

  test('registry rescue survives an Overpass failure', () async {
    final providers = Providers()
      ..osmAction = (() async => throw StateError('Overpass offline'))
      ..registryPlaces = [
          business(id: 'siret_55208131766522', siret: '55208131766522')
        ];
    final result = await providers.service().searchDetailed(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: 'hotel',
        );
    expect(result.places.single.id, 'siret_55208131766522');
    expect(result.partial, isTrue);
    expect(result.failedSources, ['OpenStreetMap']);
  });

  test('OSM results survive a registry failure through the List API', () async {
    final providers = Providers()
      ..osmPlaces = [business()]
      ..registryAction = () async => throw StateError('Registry offline');
    final result = await providers.service().search(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: 'hotel',
        );
    expect(result.single.id, 'osm:node:1');
    expect(result.single.source, 'OpenStreetMap');
  });

  test(
      'empty success plus another provider failure cannot look like no matches',
      () async {
    for (final osmFails in [false, true]) {
      final providers = Providers();
      if (osmFails) {
        providers.osmAction = () async => throw StateError('OSM offline');
      } else {
        providers.registryAction =
            () async => throw StateError('Registry offline');
      }
      await expectLater(
        providers.service().search(
              lat: 48.85,
              lng: 2.35,
              radiusMeters: 1000,
              query: 'hotel',
            ),
        throwsA(isA<DirectoryOnlineSearchException>().having(
          (error) => error.failedSources,
          'failed sources',
          hasLength(1),
        )),
      );
    }
  });

  test('two failed providers raise an explicit unavailable search error',
      () async {
    final providers = Providers()
      ..osmAction = (() async => throw StateError('OSM offline'))
      ..registryAction = (() async => throw StateError('Registry offline'));
    await expectLater(
      providers.service().search(
            lat: 48.85,
            lng: 2.35,
            radiusMeters: 1000,
            query: 'hotel',
          ),
      throwsA(isA<DirectoryOnlineSearchException>().having(
        (error) => error.failedSources,
        'failed sources',
        hasLength(2),
      )),
    );
  });

  test('the bounded wait retains completed rows and ignores a late provider',
      () async {
    final slow = Completer<List<OSMPlace>>();
    final providers = Providers()
      ..osmAction = (() => slow.future)
      ..registryPlaces = [business(id: 'registry:1')];
    final result = await providers
        .service(
          timeout: const Duration(milliseconds: 10),
        )
        .searchDetailed(
            lat: 48.85, lng: 2.35, radiusMeters: 1000, query: 'hotel');
    expect(result.places.single.id, 'registry:1');
    expect(result.partial, isTrue);
    expect(result.failedSources, ['OpenStreetMap']);
    slow.complete([business(id: 'too-late')]);
    await Future<void>.delayed(Duration.zero);
    expect(result.places.map((p) => p.id), ['registry:1']);
  });

  test('a stalled source with no completed rows raises after the bounded wait',
      () async {
    final providers = Providers()
      ..osmAction = () => Completer<List<OSMPlace>>().future;
    await expectLater(
      providers.service(timeout: const Duration(milliseconds: 10)).search(
            lat: 48.85,
            lng: 2.35,
            radiusMeters: 1000,
            query: 'hotel',
          ),
      throwsA(isA<DirectoryOnlineSearchException>()),
    );
  });

  test(
      'foreign locations and unmapped categories do not call the French registry',
      () async {
    for (final request in [
      (lat: 51.5, lng: -0.13, query: 'hotel'),
      (lat: 48.85, lng: 2.35, query: 'activité inconnue'),
    ]) {
      final providers = Providers();
      final result = await providers.service().searchDetailed(
            lat: request.lat,
            lng: request.lng,
            radiusMeters: 1000,
            query: request.query,
          );
      expect(result.places, isEmpty);
      expect(result.partial, isFalse);
      expect(providers.osmCalls, 1);
      expect(providers.registryCalls, 0);
    }
  });

  test('same exact id is returned once', () async {
    final providers = Providers()
      ..osmPlaces = [business()]
      ..registryPlaces = [business(name: 'Different name', lat: 48.9)];
    final result = await providers.service().search(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: '',
        );
    expect(result, hasLength(1));
  });

  test('same exact SIRET merges providers and preserves OSM id and contact',
      () async {
    final providers = Providers()
      ..osmPlaces = [business(phone: '0102030405', siret: '55208131766522')]
      ..registryPlaces = [
        business(
          id: 'siret_55208131766522',
          name: 'EDF',
          lat: 48.86,
          siret: '55208131766522',
          nafCode: '35.11Z',
        )
      ];
    final result = await providers.service().search(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 2000,
          query: '',
        );
    expect(result, hasLength(1));
    expect(result.single.id, 'osm:node:1');
    expect(result.single.phone, '0102030405');
    expect(result.single.siret, '55208131766522');
    expect(result.single.nafCode, '35.11Z');
    expect(result.single.source, contains('OpenStreetMap'));
    expect(result.single.source, contains('Annuaire des Entreprises'));
  });

  test('same normalized name within 35m merges and keeps legal registry data',
      () async {
    final providers = Providers()
      ..osmPlaces = [business()]
      ..registryPlaces = [
        business(
          id: 'siret_55208131766522',
          name: 'HÔTEL DE PARIS',
          lat: 48.8501,
          siret: '55208131766522',
          nafCode: '55.10Z',
        )
      ];
    final result = await providers.service().search(
          lat: 48.85,
          lng: 2.35,
          radiusMeters: 1000,
          query: 'hotel',
        );
    expect(result, hasLength(1));
    expect(result.single.id, 'osm:node:1');
    expect(result.single.siret, '55208131766522');
    expect(result.single.nafCode, '55.10Z');
  });

  test('same name beyond 35m and conflicting known SIRETs remain separate',
      () async {
    for (final registry in [
      business(id: 'registry:far', lat: 48.8505),
      business(id: 'registry:other-siret', siret: '12345678901234'),
    ]) {
      final providers = Providers()
        ..osmPlaces = [business(siret: '55208131766522')]
        ..registryPlaces = [registry];
      final result = await providers.service().search(
            lat: 48.85,
            lng: 2.35,
            radiusMeters: 1000,
            query: 'hotel',
          );
      expect(result, hasLength(2));
    }
  });
}
