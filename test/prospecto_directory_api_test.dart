import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_prospect_gps/services/prospecto_directory_api.dart';
import 'package:ai_prospect_gps/services/directory_online_search.dart';

Map<String, dynamic> fixture(String name) => jsonDecode(
        File('test/fixtures/prospecto_api_$name.json').readAsStringSync())
    as Map<String, dynamic>;
http.Response jsonResponse(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
Future<ProspectoApiSearchResult> search(ProspectoDirectoryApi api) =>
    api.searchNearby(
        lat: 48.86, lng: 2.33, radiusMeters: 2000, query: 'restaurant');

void main() {
  test('server must be a clean HTTPS origin', () {
    for (final value in [
      'http://localhost:59851',
      'https://user:pass@api.example',
      'https://api.example/path',
      'https://api.example?q=1',
      'https://api.example/#x'
    ]) {
      expect(() => ProspectoDirectoryApi(value), throwsException);
    }
  });

  test(
      'real Python API response preserves public identifiers and strict radius',
      () async {
    final requests = <Uri>[];
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((request) async {
      requests.add(request.url);
      return jsonResponse(fixture('search'));
    }));
    final result = await search(api);
    expect(result.places, hasLength(19));
    expect(result.partial, isTrue);
    expect(result.notice, contains('partielle'));
    expect(
        result.places.every((p) =>
            p.siret?.length == 14 &&
            p.nafCode != null &&
            p.source!.contains('Prospecto')),
        isTrue);
    expect(requests.single.host, 'directory.example');
    expect(requests.single.queryParameters['radius_m'], '2000');
    expect(requests.single.queryParameters['activities'], 'restaurant');
    expect(requests.single.queryParameters['page_size'], '100');
  });

  test('published catalog resolves direct download on the same server',
      () async {
    final api = ProspectoDirectoryApi('https://directory.example/',
        client: MockClient((_) async => jsonResponse(fixture('catalog'))));
    final packs = await api.catalog();
    expect(packs.single.id, 'fr-75');
    expect(packs.single.demo, isFalse);
    expect(packs.single.url!.toString(),
        startsWith('https://directory.example/v1/packs/fr-75/'));
  });

  test('catalog cannot redirect downloads to Drive or another host', () async {
    final data = fixture('catalog');
    (data['packs'] as List).first['url'] = 'https://drive.example/a.sqlite.gz';
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((_) async => jsonResponse(data)));
    await expectLater(api.catalog(), throwsFormatException);
  });

  test('own API failure does not silently query other registries', () async {
    var otherCalls = 0;
    final service = DirectoryOnlineSearch(
        api: ProspectoDirectoryApi('https://directory.example',
            client: MockClient((_) async => http.Response('', 503))),
        osmSearch: (
            {required lat,
            required lng,
            required radiusMeters,
            required query,
            required languageCode}) async {
          otherCalls++;
          return [];
        },
        registrySearch: (
            {required lat,
            required lng,
            required radiusMeters,
            required query}) async {
          otherCalls++;
          return [];
        });
    await expectLater(
        service.searchDetailed(
            lat: 48.86, lng: 2.33, radiusMeters: 2000, query: 'restaurant'),
        throwsException);
    expect(otherCalls, 0);
  });

  test(
      'own partial coverage is preserved without a fictitious provider failure',
      () async {
    final service = DirectoryOnlineSearch(
        api: ProspectoDirectoryApi('https://directory.example',
            client: MockClient((_) async => jsonResponse(fixture('search')))));
    final result = await service.searchDetailed(
        lat: 48.86, lng: 2.33, radiusMeters: 2000, query: 'restaurant');
    expect(result.partial, isTrue);
    expect(result.failedSources, isEmpty);
    expect(result.places, hasLength(19));
  });

  test('pagination stays bounded, deduplicates SIRET and reports its limit',
      () async {
    var requests = 0;
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((request) async {
      requests++;
      final data = fixture('search');
      final page = int.parse(request.url.queryParameters['page']!);
      data['pagination'] = {
        'page': page,
        'page_size': 100,
        'total': 600,
        'next_page': page + 1
      };
      return jsonResponse(data);
    }));
    final result = await search(api);
    expect(requests, 5);
    expect(result.places, hasLength(19));
    expect(result.notice, contains('500'));
    expect(result.partial, isTrue);
  });

  test('429 imposes a cooldown instead of retrying in a loop', () async {
    var requests = 0;
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((_) async {
      requests++;
      return http.Response('', 429, headers: {'retry-after': '10'});
    }));
    await expectLater(search(api), throwsException);
    await expectLater(search(api), throwsException);
    expect(requests, 1);
  });

  test('out of radius or malformed records never become prospects', () async {
    for (final value in [null, 0.0, '48.8']) {
      final data = fixture('search');
      (data['results'] as List).first['lat'] = value;
      final api = ProspectoDirectoryApi('https://directory.example',
          client: MockClient((_) async => jsonResponse(data)));
      await expectLater(search(api), throwsException);
    }
  });

  test(
      'an imported public place without SIRET keeps its source ID without inventing a SIRET',
      () async {
    final data = fixture('search');
    final row = (data['results'] as List).first;
    row['id'] = 'osm:node:123';
    row['siret'] = null;
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((_) async => jsonResponse(data)));
    final result = await search(api);
    expect(result.places.first.id, 'osm:node:123');
    expect(result.places.first.siret, isNull);
  });

  test('oversized bodies and HTTP redirects are rejected', () async {
    for (final response in [
      http.Response('x' * (4 * 1024 * 1024 + 1), 200),
      http.Response('', 302, headers: {'location': 'https://other.example'})
    ]) {
      final api = ProspectoDirectoryApi('https://directory.example',
          client: MockClient((_) async => response));
      await expectLater(search(api), throwsException);
    }
  });

  test('version change across pages asks for a fresh search', () async {
    var requests = 0;
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((_) async {
      final data = fixture('search');
      requests++;
      if (requests == 1) {
        (data['pagination'] as Map)['next_page'] = 2;
      } else {
        data['version'] = 'new-release';
      }
      return jsonResponse(data);
    }));
    await expectLater(search(api), throwsException);
    expect(requests, 2);
  });
}
