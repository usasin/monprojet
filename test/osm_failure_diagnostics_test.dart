import 'dart:async';

import 'package:ai_prospect_gps/services/osm_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _privateDetail = 'private-address-43.2965-secret.example';

OSMSearchService _service(
    FutureOr<http.Response> Function(http.Request) handler,
    {List<String>? endpoints}) {
  final client = MockClient((request) async => await handler(request));
  addTearDown(client.close);
  var now = DateTime.utc(2026, 10, 25);
  return OSMSearchService(
    client: client,
    now: () => now,
    wait: (duration) async => now = now.add(duration),
    overpassEndpoints: endpoints ?? ['https://diagnostic.test/interpreter'],
  );
}

Future<Object> _search(OSMSearchService service, bool geocode) => geocode
    ? service.geocodeOptions('$_privateDetail, Paris, France')
    : service.searchNearby(
        lat: 43.2965,
        lng: 5.3698,
        query: _privateDetail,
        radiusMeters: 1000,
      );

Future<OSMSearchException> _failure(Future<Object> future) async {
  try {
    await future;
    fail('A diagnostic exception was expected');
  } on OSMSearchException catch (error) {
    expect(error.toString(), isNot(contains(_privateDetail)));
    expect(error.messageFor('en'), isNot(contains(_privateDetail)));
    expect(error.messageFor('fr'), isNot(contains(_privateDetail)));
    return error;
  }
}

void main() {
  for (final geocode in [false, true]) {
    final serviceName = geocode ? 'Nominatim' : 'Overpass';
    for (final entry in <int, String>{
      400: 'invalid_query',
      401: 'forbidden',
      403: 'forbidden',
      429: 'server_busy',
      500: 'server_error',
      502: 'server_busy',
      503: 'server_busy',
      504: 'server_busy',
    }.entries) {
      test('$serviceName distinguishes HTTP ${entry.key}', () async {
        final service =
            _service((_) => http.Response(_privateDetail, entry.key));
        final error = await _failure(_search(service, geocode));
        expect(error.code, entry.value);
        expect(error.messageFor('en'), isNot(error.messageFor('fr')));
      });
    }

    test('$serviceName reports a connection failure without leaking details',
        () async {
      final service =
          _service((_) => throw http.ClientException(_privateDetail));
      final error = await _failure(_search(service, geocode));
      expect(error.code, 'no_network');
      expect(error.messageFor('fr'), contains('Connexion'));
    });

    test('$serviceName distinguishes timeout from service overload', () async {
      final service = _service((_) => throw TimeoutException(_privateDetail));
      final error = await _failure(_search(service, geocode));
      expect(error.code, 'timeout');
    });

    test('$serviceName distinguishes invalid JSON from a network failure',
        () async {
      final service = _service((_) => http.Response(_privateDetail, 200));
      final error = await _failure(_search(service, geocode));
      expect(error.code, 'invalid_response');
    });
  }

  test('HTTP 200 Overpass remark is an incomplete response diagnostic',
      () async {
    final service = _service((_) => http.Response(
        '{"remark":"runtime error $_privateDetail", "elements":[]}', 200));
    final error = await _failure(_search(service, false));
    expect(error.code, 'invalid_response');
    expect(error.messageFor('fr'), contains('incomplète'));
  });

  test('cooldown preserves the latest failure without issuing more requests',
      () async {
    var calls = 0;
    final service = _service((_) {
      calls += 1;
      if (calls == 1) return http.Response(_privateDetail, 502);
      throw http.ClientException(_privateDetail);
    }, endpoints: [
      'https://diagnostic-a.test/interpreter',
      'https://diagnostic-b.test/interpreter',
    ]);
    expect((await _failure(_search(service, false))).code, 'no_network');
    expect(calls, 2);
    expect((await _failure(_search(service, false))).code, 'no_network');
    expect(calls, 2);
  });

  test('unclassified client failures receive a distinct safe diagnostic',
      () async {
    final service = _service((_) => throw StateError(_privateDetail));
    expect((await _failure(_search(service, false))).code, 'client_error');
  });

  test('legacy constructor and toString remain compatible', () {
    const error = OSMSearchException('Public message');
    expect(error.code, 'unknown');
    expect(error.toString(), 'Public message');
  });
}
