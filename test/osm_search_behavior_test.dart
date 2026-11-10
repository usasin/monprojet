import 'dart:async';
import 'dart:convert';

import 'package:ai_prospect_gps/models/prospect.dart';
import 'package:ai_prospect_gps/services/osm_search_service.dart';
import 'package:ai_prospect_gps/services/smart_route_planner.dart';
import 'package:ai_prospect_gps/services/week_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _marseilleLat = 43.2965;
const _marseilleLng = 5.3698;
const _mirrors = <String>[
  'https://mirror-a.test/api/interpreter',
  'https://mirror-b.test/api/interpreter',
  'https://mirror-c.test/api/interpreter',
];

class _Clock {
  DateTime value = DateTime.utc(2026, 10, 25, 12);
  final waits = <Duration>[];

  DateTime now() => value;

  void advance(Duration duration) => value = value.add(duration);

  Future<void> wait(Duration duration) async {
    waits.add(duration);
    advance(duration);
  }
}

OSMSearchService _service(
  FutureOr<http.Response> Function(http.Request) handler, {
  _Clock? clock,
  Duration overpassTimeout = const Duration(seconds: 18),
}) {
  final effectiveClock = clock ?? _Clock();
  final client = MockClient((request) async => await handler(request));
  addTearDown(client.close);
  return OSMSearchService(
    client: client,
    now: effectiveClock.now,
    wait: effectiveClock.wait,
    overpassTimeout: overpassTimeout,
    overpassEndpoints: _mirrors,
  );
}

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, Object?> _location(
  Object? lat,
  Object? lng, {
  String name = 'Marseille, France',
}) =>
    {'lat': lat, 'lon': lng, 'display_name': name};

Map<String, Object?> _place({
  int id = 1,
  double lat = _marseilleLat,
  double lng = _marseilleLng,
  Map<String, Object?>? tags,
}) =>
    {
      'type': 'node',
      'id': id,
      'lat': lat,
      'lon': lng,
      'tags': tags ?? {'name': 'Restaurant du Port', 'amenity': 'restaurant'},
    };

http.Response _places([List<Object?>? elements]) => _json({
      'elements': elements ?? [_place()]
    });

Future<List<OSMPlace>> _nearby(
  OSMSearchService service, {
  String query = 'restaurant',
  double lat = _marseilleLat,
  double lng = _marseilleLng,
  int radius = 1000,
}) =>
    service.searchNearby(
      lat: lat,
      lng: lng,
      query: query,
      radiusMeters: radius,
      languageCode: 'fr',
    );

String _query(http.Request request) =>
    Uri.splitQueryString(request.body)['data']!;

// This small fake Overpass interpreter evaluates selectors against real tag
// fixtures. Category tests exercise request construction AND returned businesses
// rather than comparing the service source with a copy of its query strings.
bool _matchesSelectors(Map<String, Object?> tags, String query) {
  final clauses = RegExp(r'nwr((?:\[[^\]]+\])+)\(around:')
      .allMatches(query)
      .map((match) => match.group(1)!);
  for (final clause in clauses) {
    var matches = true;
    for (final condition in RegExp(r'\[([^\]]+)\]').allMatches(clause)) {
      final selector =
          RegExp(r'^"((?:\\.|[^"\\])*)"(?:([=~])"((?:\\.|[^"\\])*)"(?:,i)?)?$')
              .firstMatch(condition.group(1)!);
      if (selector == null) {
        throw StateError('Unsupported test selector: ${condition.group(1)}');
      }
      final key = jsonDecode('"${selector.group(1)}"') as String;
      final expected = selector.group(3) == null
          ? null
          : jsonDecode('"${selector.group(3)}"') as String;
      final value = tags[key]?.toString();
      if (value == null ||
          (selector.group(2) == '=' && value != expected) ||
          (selector.group(2) == '~' &&
              !RegExp(expected!, caseSensitive: false).hasMatch(value))) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

void main() {
  group('Nominatim address tolerance and confirmation', () {
    test('a city alone works internationally without a country filter',
        () async {
      final requests = <http.Request>[];
      final service = _service((request) {
        requests.add(request);
        return _json([
          _location('51.5074', '-0.1278', name: 'London, United Kingdom'),
        ]);
      });

      final result = await service.geocodeOptions('London');

      expect(result.options.single.lat, 51.5074);
      expect(result.options.single.lng, -0.1278);
      expect(result.options.single.displayName, 'London, United Kingdom');
      expect(result.isFallback, isFalse);
      expect(requests.single.url.queryParameters['q'], 'London');
      expect(requests.single.url.queryParameters['countrycodes'], isNull);
      expect(requests.single.url.queryParameters['limit'], '5');
    });

    test('a street and city work without house number or country', () async {
      final service = _service((request) {
        expect(request.url.queryParameters['q'], 'Baker Street, London');
        return _json([
          _location('51.5237', '-0.1585', name: 'Baker Street, London'),
        ]);
      });

      final point = await service.geocode('Baker Street, London');

      expect(point.lat, 51.5237);
      expect(point.lng, -0.1585);
    });

    test('extra spaces and comma spacing share one normalized query', () async {
      final requests = <http.Request>[];
      final service = _service((request) {
        requests.add(request);
        return _json([_location('51.5034', '-0.1276')]);
      });

      await service.geocode('  10   Downing Street ,  London , UK  ');
      await service.geocode('10 Downing Street, London, UK');

      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['q'],
          '10 Downing Street, London, UK');
    });

    test('an unfound house number offers a clearly marked street fallback',
        () async {
      final queries = <String>[];
      final service = _service((request) {
        final q = request.url.queryParameters['q']!;
        queries.add(q);
        return q.startsWith('999 ')
            ? _json([])
            : _json([
                _location('43.2899', '5.3798', name: 'Rue Paradis, Marseille'),
              ]);
      });

      final result =
          await service.geocodeOptions('999 Rue Paradis, Marseille, France');

      expect(queries, [
        '999 Rue Paradis, Marseille, France',
        'Rue Paradis, Marseille, France'
      ]);
      expect(result.isFallback, isTrue);
      expect(result.queryUsed, 'Rue Paradis, Marseille, France');
      expect(result.options.single.displayName, 'Rue Paradis, Marseille');
    });

    test('a misspelled street can offer the explicit city, never the country',
        () async {
      final queries = <String>[];
      final service = _service((request) {
        final q = request.url.queryParameters['q']!;
        queries.add(q);
        return q == 'Marseille, France'
            ? _json([_location('43.2965', '5.3698')])
            : _json([]);
      });

      final result =
          await service.geocodeOptions('999 Rue Pardis, Marseille, France');

      expect(queries, [
        '999 Rue Pardis, Marseille, France',
        'Rue Pardis, Marseille, France',
        'Marseille, France',
      ]);
      expect(result.queryUsed, 'Marseille, France');
      expect(result.isFallback, isTrue);
      expect(result.options.single.lat, _marseilleLat);
    });

    test('an ambiguous unknown city is not silently replaced by a country',
        () async {
      final queries = <String>[];
      final service = _service((request) {
        queries.add(request.url.queryParameters['q']!);
        return _json([]);
      });

      await expectLater(
          service.geocodeOptions('Marselle, France'), throwsException);

      expect(queries, ['Marselle, France']);
    });

    test(
        'a street and city without country can offer a confirmed city fallback',
        () async {
      final queries = <String>[];
      final service = _service((request) {
        final q = request.url.queryParameters['q']!;
        queries.add(q);
        return q == 'Marseille'
            ? _json([
                {
                  ..._location('43.2965', '5.3698'),
                  'type': 'administrative',
                  'addresstype': 'city',
                },
              ])
            : _json([]);
      });

      final result = await service.geocodeOptions('12 rue Fausse, Marseille');

      expect(queries,
          ['12 rue Fausse, Marseille', 'rue Fausse, Marseille', 'Marseille']);
      expect(result.isFallback, isTrue);
      expect(result.queryUsed, 'Marseille');
      expect(result.options.single.lat, _marseilleLat);
    });

    test('a two-part street fallback refuses a country or region candidate',
        () async {
      final service = _service((request) {
        return request.url.queryParameters['q'] == 'Marseille'
            ? _json([
                {
                  ..._location('46.6', '1.9', name: 'France'),
                  'type': 'administrative',
                  'addresstype': 'country',
                },
              ])
            : _json([]);
      });

      await expectLater(
        service.geocodeOptions('12 rue Fausse, Marseille'),
        throwsException,
      );
    });

    for (final status in [429, 503]) {
      test('HTTP $status does not pretend the address is unfound', () async {
        final queries = <String>[];
        final service = _service((request) {
          queries.add(request.url.queryParameters['q']!);
          return http.Response('provider unavailable', status);
        });

        await expectLater(
          service.geocodeOptions('999 Rue Paradis, Marseille, France'),
          throwsException,
        );

        expect(queries, ['999 Rue Paradis, Marseille, France']);
      });
    }

    test('ambiguous candidates stay available for user confirmation', () async {
      final service = _service((_) => _json([
            _location('39.7817', '-89.6501',
                name: 'Springfield, Illinois, USA'),
            _location('42.1015', '-72.5898',
                name: 'Springfield, Massachusetts, USA'),
          ]));

      final result = await service.geocodeOptions('Springfield');

      expect(result.options, hasLength(2));
      expect(result.options.map((e) => e.displayName), [
        'Springfield, Illinois, USA',
        'Springfield, Massachusetts, USA',
      ]);
      expect(result.isFallback, isFalse);
    });

    test('invalid coordinates are skipped while equator and zero stay valid',
        () async {
      final service = _service((_) => _json([
            _location(null, '31'),
            _location('NaN', '31'),
            _location('91', '31'),
            _location('0', '181'),
            _location('0', '31', name: 'Equator'),
            _location('0', '0', name: 'Zero'),
          ]));

      final result = await service.geocodeOptions('Equator');

      expect(result.options.map((e) => e.displayName), ['Equator', 'Zero']);
      expect(result.options.first.lat, 0);
      expect(result.options.last.lng, 0);
    });

    test(
        'a malformed response triggers neither address fallback nor a cache hit',
        () async {
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return calls == 1
            ? _json({'error': 'invalid upstream response'})
            : _json([_location('43.2965', '5.3698')]);
      });

      await expectLater(service.geocodeOptions('Marseille'), throwsException);
      expect((await service.geocodeOptions('Marseille')).options, hasLength(1));
      expect(calls, 2);
    });

    test('simultaneous normalized requests share the same HTTP call', () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return response.future;
      });

      final first = service.geocodeOptions(' Marseille ');
      final second = service.geocodeOptions('Marseille');
      response.complete(_json([_location('43.2965', '5.3698')]));
      final results = await Future.wait([first, second]);

      expect(calls, 1);
      expect(results[0].options.single.lat, results[1].options.single.lat);
    });

    test('different Nominatim requests are spaced by at least one second',
        () async {
      final clock = _Clock();
      final starts = <DateTime>[];
      final service = _service((_) {
        starts.add(clock.now());
        return _json([_location('43.2965', '5.3698')]);
      }, clock: clock);

      await Future.wait([
        service.geocodeOptions('Marseille'),
        service.geocodeOptions('London'),
      ]);

      expect(starts, hasLength(2));
      expect(starts.last.difference(starts.first),
          greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    test('Nominatim Retry-After prevents further HTTP calls during cooldown',
        () async {
      final clock = _Clock();
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return calls == 1
            ? http.Response('busy', 429, headers: {'retry-after': '120'})
            : _json([_location('43.2965', '5.3698')]);
      }, clock: clock);

      await expectLater(service.geocodeOptions('Marseille'), throwsException);
      clock.advance(const Duration(seconds: 76));
      await expectLater(service.geocodeOptions('London'), throwsException);
      expect(calls, 1);
      clock.advance(const Duration(seconds: 45));
      expect((await service.geocodeOptions('London')).options, hasLength(1));
      expect(calls, 2);
    });

    test('expired geocoding cache never silently supplies an old location',
        () async {
      final clock = _Clock();
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        if (calls == 1) return _json([_location('43.2965', '5.3698')]);
        throw http.ClientException('offline');
      }, clock: clock);

      await service.geocodeOptions('Marseille');
      clock.advance(const Duration(hours: 2));
      await expectLater(service.geocodeOptions('Marseille'), throwsException);
      expect(calls, 2);
    });
  });

  group('Overpass recovery and honest results', () {
    test('node output requests coordinates instead of discarding every node',
        () async {
      final service = _service((request) {
        final output =
            RegExp(r'out\s+([^;]+);').firstMatch(_query(request))!.group(1)!;
        final node = _place();
        // Overpass tags verbosity omits node latitude and longitude. `center`
        // supplies way/relation centers but cannot repair node tags output.
        if (RegExp(r'\btags\b').hasMatch(output)) {
          node.remove('lat');
          node.remove('lon');
        }
        return _places([node]);
      });

      final places = await _nearby(service);

      expect(places.single.id, 'node_1');
      expect(places.single.lat, _marseilleLat);
      expect(places.single.lng, _marseilleLng);
    });

    test('429 uses a mirror and respects the full Retry-After duration',
        () async {
      final clock = _Clock();
      final hosts = <String>[];
      final service = _service((request) {
        hosts.add(request.url.host);
        if (hosts.length == 1) {
          return http.Response('busy', 429, headers: {'retry-after': '120'});
        }
        return _places();
      }, clock: clock);

      expect(await _nearby(service), hasLength(1));
      clock.advance(const Duration(seconds: 76));
      expect(await _nearby(service, query: 'coiffeur'), hasLength(1));
      clock.advance(const Duration(seconds: 45));
      expect(await _nearby(service, query: 'GMS'), hasLength(1));

      expect(hosts, [
        'mirror-a.test',
        'mirror-b.test',
        'mirror-b.test',
        'mirror-a.test',
      ]);
    });

    test('a 5xx mirror is bypassed and the successful response is parsed',
        () async {
      final hosts = <String>[];
      final service = _service((request) {
        hosts.add(request.url.host);
        return hosts.length == 1
            ? http.Response('unavailable', 503)
            : _places();
      });

      final places = await _nearby(service);

      expect(hosts, ['mirror-a.test', 'mirror-b.test']);
      expect(places.single.name, 'Restaurant du Port');
    });

    test('a slow mirror times out and the next mirror supplies usable places',
        () async {
      final slow = Completer<http.Response>();
      final hosts = <String>[];
      final service = _service((request) {
        hosts.add(request.url.host);
        return hosts.length == 1 ? slow.future : _places();
      }, overpassTimeout: const Duration(milliseconds: 10));

      try {
        final places = await _nearby(service);
        expect(places.single.id, 'node_1');
        expect(hosts, ['mirror-a.test', 'mirror-b.test']);
      } finally {
        slow.complete(_places());
      }
    });

    for (final invalid in <String>[
      '<html>proxy error</html>',
      '{}',
      '{"elements":[],"remark":"runtime error: Query timed out"}',
    ]) {
      test('an invalid HTTP 200 response uses a healthy mirror: $invalid',
          () async {
        final hosts = <String>[];
        final service = _service((request) {
          hosts.add(request.url.host);
          return hosts.length == 1 ? http.Response(invalid, 200) : _places();
        });

        final places = await _nearby(service);

        expect(hosts, ['mirror-a.test', 'mirror-b.test']);
        expect(places.single.name, 'Restaurant du Port');
        expect(await _nearby(service), hasLength(1));
        expect(hosts, hasLength(2));
      });
    }

    test('an invalid provider response is never cached as an empty area',
        () async {
      final clock = _Clock();
      var valid = false;
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return valid
            ? _places()
            : _json({'remark': 'runtime error: out of memory', 'elements': []});
      }, clock: clock);

      await expectLater(_nearby(service), throwsException);
      final failedCalls = calls;
      expect(failedCalls, 3);
      valid = true;
      clock.advance(const Duration(minutes: 2));
      expect(await _nearby(service), hasLength(1));
      expect(calls, greaterThan(failedCalls));
    });

    test('a valid empty area is returned and cached as empty', () async {
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return _places([]);
      });

      expect(await _nearby(service), isEmpty);
      expect(await _nearby(service), isEmpty);
      expect(calls, 1);
    });

    test('offline searches fail visibly instead of returning an empty list',
        () async {
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        throw http.ClientException('offline');
      });

      await expectLater(_nearby(service), throwsException);
      expect(calls, 3);
    });

    test('HTTP 400 stops retries because the query itself was rejected',
        () async {
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return http.Response('bad query', 400);
      });

      await expectLater(_nearby(service), throwsException);
      expect(calls, 1);
    });

    test('one malformed element cannot discard valid in-radius businesses',
        () async {
      final service = _service((_) => _places([
            null,
            'invalid element',
            {'type': 'node', 'id': 8, 'lat': 'not-a-number', 'lon': 5.3},
            {'type': 'node', 'id': 9, 'lat': 93, 'lon': 5.3},
            {'type': 'node', 'id': 10, 'center': 'invalid center'},
            _place(id: 1, lat: _marseilleLat + .001),
            _place(id: 1, lat: _marseilleLat + .001),
            _place(id: 2, lat: _marseilleLat + .02),
            _place(id: 3, tags: {'name': 'Bus', 'highway': 'bus_stop'}),
            _place(id: 4, tags: {'amenity': 'restaurant'}),
            {
              'type': 'way',
              'id': 5,
              'center': {'lat': _marseilleLat, 'lon': _marseilleLng},
              'tags': {
                'name': 'Salon du Port',
                'shop': 'hairdresser',
                'addr:housenumber': '10',
                'addr:street': 'Rue du Port',
                'addr:city': 'Marseille',
                'contact:phone': '+33 4 00 00 00 00',
              },
            },
          ]));

      final places = await _nearby(service, radius: 500);

      expect(places.map((e) => e.id), ['way_5', 'node_1']);
      expect(places.first.address, contains('Rue du Port'));
      expect(places.first.phone, '+33 4 00 00 00 00');
      expect(places.first.category, 'Coiffure');
    });

    test('the radius stays strict at 500 m, 1 km and 2 km', () async {
      final service = _service((_) => _places([
            _place(id: 1, lat: _marseilleLat + .003),
            _place(id: 2, lat: _marseilleLat + .007),
            _place(id: 3, lat: _marseilleLat + .014),
            _place(id: 4, lat: _marseilleLat + .025),
          ]));

      expect(
          (await _nearby(service, radius: 500)).map((e) => e.id), ['node_1']);
      expect((await _nearby(service, radius: 1000)).map((e) => e.id),
          ['node_1', 'node_2']);
      expect((await _nearby(service, radius: 2000)).map((e) => e.id),
          ['node_1', 'node_2', 'node_3']);
    });

    test('equator businesses with zero latitude are valid', () async {
      final service = _service((_) => _places([
            _place(lat: 0, lng: 31),
          ]));

      expect(await _nearby(service, lat: 0, lng: 31), hasLength(1));
    });

    test('simultaneous searches share HTTP and successful results are cached',
        () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return response.future;
      });

      final first = _nearby(service);
      final second = _nearby(service);
      response.complete(_places());
      final results = await Future.wait([first, second]);
      expect(results.map((e) => e.single.id), ['node_1', 'node_1']);
      expect(await _nearby(service), hasLength(1));
      expect(calls, 1);
    });

    test('expired nearby cache does not conceal a provider outage', () async {
      final clock = _Clock();
      var calls = 0;
      final service = _service((_) {
        calls += 1;
        return calls == 1 ? _places() : http.Response('unavailable', 503);
      }, clock: clock);

      await _nearby(service);
      clock.advance(const Duration(minutes: 6));
      await expectLater(_nearby(service), throwsException);
      expect(calls, 4);
    });
  });

  group('profession mapping through simulated Overpass responses', () {
    final catalog = <Map<String, Object?>>[
      {'name': 'Salon', 'shop': 'hairdresser'},
      {'name': 'Restaurant', 'amenity': 'restaurant'},
      {'name': 'Café', 'amenity': 'cafe'},
      {'name': 'Hôtel', 'tourism': 'hotel'},
      {'name': 'Bar', 'amenity': 'bar'},
      {'name': 'Supermarché', 'shop': 'supermarket'},
      {'name': 'Grand magasin', 'shop': 'department_store'},
      {'name': 'Grossiste', 'shop': 'wholesale'},
      {'name': 'Épicerie', 'shop': 'convenience'},
      {'name': 'Parapharmacie', 'shop': 'chemist'},
      {'name': 'Beauté santé', 'shop': 'health_and_beauty'},
      {'name': 'Médecin', 'amenity': 'doctors'},
      {'name': 'Bureau', 'office': 'consulting'},
      {'name': 'Artisan', 'craft': 'electrician'},
      {'name': 'Menuisier', 'craft': 'carpenter'},
      {'name': 'Usine', 'man_made': 'works', 'industrial': 'factory'},
      {'name': 'Entrepôt', 'building': 'warehouse'},
      {'name': 'Logistique', 'office': 'logistics'},
      {'name': 'Transport', 'office': 'transport'},
    ];

    final scenarios = <String, List<String>>{
      'coiffeur': ['Salon'],
      'restaurant': ['Restaurant', 'Café'],
      'CHR': ['Restaurant', 'Café', 'Hôtel', 'Bar'],
      'HORECA': ['Restaurant', 'Café', 'Hôtel', 'Bar'],
      'GMS': ['Supermarché', 'Grand magasin', 'Grossiste'],
      'parapharmacies': ['Parapharmacie', 'Beauté santé'],
      'drugstore': ['Parapharmacie', 'Beauté santé'],
      'entreprises': [
        'Bureau',
        'Artisan',
        'Menuisier',
        'Usine',
        'Entrepôt',
        'Logistique',
        'Transport'
      ],
      'TPE': [
        'Bureau',
        'Artisan',
        'Menuisier',
        'Usine',
        'Entrepôt',
        'Logistique',
        'Transport'
      ],
      'PME': [
        'Bureau',
        'Artisan',
        'Menuisier',
        'Usine',
        'Entrepôt',
        'Logistique',
        'Transport'
      ],
      'artisans': ['Artisan', 'Menuisier'],
      'carpenter': ['Menuisier'],
      'entrepôts': ['Entrepôt', 'Logistique', 'Transport'],
      'transport': ['Entrepôt', 'Logistique', 'Transport'],
      'logistique': ['Entrepôt', 'Logistique', 'Transport'],
      'coiffeur, restaurant': ['Salon', 'Restaurant', 'Café'],
    };

    for (final scenario in scenarios.entries) {
      test('Marseille: ${scenario.key} returns the matching businesses',
          () async {
        var calls = 0;
        final service = _service((request) {
          calls += 1;
          expect(request.method, 'POST');
          final query = _query(request);
          expect(query, contains('(around:1000,43.2965,5.3698)'));
          final matching = <Object?>[];
          for (var i = 0; i < catalog.length; i += 1) {
            if (_matchesSelectors(catalog[i], query)) {
              matching.add(_place(id: i + 1, tags: catalog[i]));
            }
          }
          return _places(matching);
        });

        final places = await _nearby(service, query: scenario.key);

        expect(places.map((e) => e.name), unorderedEquals(scenario.value));
        expect(calls, 1);
      });
    }

    test('industrial buildings do not acquire an invented company size',
        () async {
      final service = _service((_) => _places([
            _place(id: 1, tags: {'name': 'Usine', 'man_made': 'works'}),
            _place(id: 2, tags: {'name': 'Entrepôt', 'building': 'warehouse'}),
          ]));

      for (final query in ['TPE', 'PME', 'grandes entreprises']) {
        final places = await _nearby(service, query: query);
        expect(places, hasLength(2));
        for (final place in places) {
          expect(place.category, isNot(query));
          expect(RegExp('tpe|pme|grand').hasMatch(place.category.toLowerCase()),
              isFalse);
          expect(place.category, isNotEmpty);
        }
      }
    });

    for (final name in ['O\'Reilly "A+B"', 'Alpha .*']) {
      test('unknown business text remains literal and quoted safely: $name',
          () async {
        final service = _service((request) {
          final query = _query(request);
          final catalog = <Map<String, Object?>>[
            {'name': name, 'shop': 'hairdresser'},
            {'name': 'Alpha Coffee', 'shop': 'hairdresser'},
            {'name': 'OReilly AAB', 'shop': 'hairdresser'},
          ];
          return _places([
            for (var i = 0; i < catalog.length; i += 1)
              if (_matchesSelectors(catalog[i], query))
                _place(id: i + 1, tags: catalog[i]),
          ]);
        });

        final places = await _nearby(service, query: name);

        expect(places.map((e) => e.name), [name]);
      });
    }

    test('London city geocoding drives an international prospect search',
        () async {
      final requests = <http.Request>[];
      final service = _service((request) {
        requests.add(request);
        if (request.method == 'GET') {
          return _json([
            _location('51.5074', '-0.1278', name: 'London, United Kingdom'),
          ]);
        }
        expect(_query(request), contains('(around:500,51.5074,-0.1278)'));
        return _places([
          _place(
            id: 12,
            lat: 51.5075,
            lng: -0.1278,
            tags: {
              'name': 'London Coffee',
              'amenity': 'cafe',
              'addr:street': 'Whitehall',
              'addr:city': 'London',
              'addr:postcode': 'SW1A 2AA',
              'addr:country': 'GB',
            },
          ),
        ]);
      });

      final location = await service.geocodeOptions('London');
      final chosen = location.options.single;
      final prospects = await _nearby(
        service,
        query: 'HORECA',
        lat: chosen.lat,
        lng: chosen.lng,
        radius: 500,
      );

      expect(requests.map((e) => e.method), ['GET', 'POST']);
      expect(prospects.single.name, 'London Coffee');
      expect(prospects.single.address, contains('London'));
      expect(prospects.single.address, contains('GB'));
    });
  });

  test('search, selection, local route and week planning preserve chosen IDs',
      () async {
    final requests = <http.Request>[];
    final service = _service((request) {
      requests.add(request);
      if (request.method == 'GET') {
        return _json([_location('43.2965', '5.3698')]);
      }
      return _places([
        for (var i = 1; i <= 4; i += 1)
          _place(
            id: i,
            lat: _marseilleLat + i * .0005,
            lng: _marseilleLng + i * .0002,
            tags: {
              'name': 'Professionnel $i',
              'shop': 'hairdresser',
              'addr:housenumber': '$i',
              'addr:street': 'Rue du Port',
              'addr:city': 'Marseille',
              'opening_hours': 'Mo-Fr 09:00-18:00',
              'phone': '+33 4 00 00 00 0$i',
            },
          ),
      ]);
    });

    final location = (await service.geocodeOptions('Marseille')).options.single;
    final found = await _nearby(service,
        query: 'coiffeur', lat: location.lat, lng: location.lng, radius: 500);
    final prospects = [
      for (final place in found)
        Prospect(
          id: place.id,
          name: place.name,
          address: place.address,
          category: place.category,
          lat: place.lat,
          lng: place.lng,
          phone: place.phone,
          openingHours: place.openingHours,
        ),
    ];
    const chosenIds = {'node_1', 'node_3', 'node_4'};
    final chosen = prospects.where((p) => chosenIds.contains(p.id)).toList();
    final constraints = PlannerConstraints(
      day: DateTime(2026, 10, 26),
      start: PlannerPoint(
        lat: location.lat,
        lng: location.lng,
        label: location.displayName,
      ),
      workStartMinutes: 9 * 60,
      workEndMinutes: 12 * 60,
      maxStops: 3,
      trafficAware: false,
    );
    final route = await const SmartRoutePlanner().build(
      prospects: chosen,
      constraints: constraints,
    );

    expect(prospects, hasLength(4));
    expect(chosen, hasLength(3));
    expect(route.unscheduled, isEmpty);
    expect(route.stops.map((s) => s.prospect.id), unorderedEquals(chosenIds));
    expect(route.stops.map((s) => s.prospect.id).toSet(), hasLength(3));
    expect(route.usedLiveTraffic, isFalse);
    expect(
        route.totalTravel.inSeconds,
        route.stops
            .fold<int>(0, (sum, stop) => sum + stop.travelDuration.inSeconds));
    expect(route.totalDistanceMeters,
        route.stops.fold<int>(0, (sum, stop) => sum + stop.distanceMeters));
    var previousDeparture = constraints.atMinute(constraints.workStartMinutes);
    for (final stop in route.stops) {
      expect(stop.arrival, previousDeparture.add(stop.travelDuration));
      expect(stop.startVisit.isBefore(stop.arrival), isFalse);
      expect(stop.departure.difference(stop.startVisit),
          const Duration(minutes: 30));
      expect(
          stop.departure
              .isAfter(constraints.atMinute(constraints.workEndMinutes)),
          isFalse);
      expect(stop.prospect.phone, isNotNull);
      previousDeparture = stop.departure;
    }

    final week = WeekPlanner.build(
      prospects: route.stops.map((s) => s.prospect).toList(),
      monday: DateTime(2026, 10, 28),
      maxPerDay: 2,
    );
    final weeklyIds = week.days.expand((day) => day).map((p) => p.id).toList();

    expect(week.monday, DateTime(2026, 10, 26));
    expect(week.days, hasLength(5));
    expect(week.days.every((day) => day.length <= 2), isTrue);
    expect(week.remaining, isEmpty);
    expect(weeklyIds, unorderedEquals(chosenIds));
    expect(weeklyIds.toSet(), hasLength(3));
    // Only the mock Nominatim/Overpass calls are needed by this local pipeline.
    expect(requests.map((r) => r.method), ['GET', 'POST']);
  });
}
