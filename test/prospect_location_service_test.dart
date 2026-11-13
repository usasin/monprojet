import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:location/location.dart';
import 'package:ai_prospect_gps/services/prospect_location_service.dart';

Map<String, Object?> address(String label, double lon, double lat,
        {String type = 'housenumber', String postcode = '75001'}) =>
    {
      'properties': {'label': label, 'type': type, 'postcode': postcode},
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat]
      },
    };
http.Response response(List<Object?> features) =>
    http.Response(jsonEncode({'features': features}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

class TestLocation extends Fake implements Location {
  bool enabled = true;
  PermissionStatus permission = PermissionStatus.granted;
  int reads = 0, permissionRequests = 0;
  @override
  Future<bool> serviceEnabled() async => enabled;
  @override
  Future<bool> requestService() async => enabled;
  @override
  Future<PermissionStatus> hasPermission() async => permission;
  @override
  Future<PermissionStatus> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<LocationData> getLocation() async {
    reads++;
    return LocationData.fromMap(
        {'latitude': 48.86, 'longitude': 2.33, 'accuracy': 12.0});
  }
}

void main() {
  test(
      'street lookup preserves multiple choices and distinguishes precise from broad centre',
      () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'data.geopf.fr');
      expect(request.url.queryParameters['limit'], '6');
      return response([
        address('10 Rue de Rivoli 75004 Paris', 2.36041, 48.8555),
        address('Rue de Rivoli 75001 Paris', 2.3362, 48.862442, type: 'street')
      ]);
    });
    addTearDown(client.close);
    final places = await ProspectLocationService(client: client)
        .search('10 rue de Rivoli Paris');
    expect(places.length, 2);
    expect(places.first.preciseAddress, isTrue);
    expect(places.last.preciseAddress, isFalse);
    expect(places.first.lon, 2.36041);
  });
  test(
      'postcode lookup asks for municipality choices and keeps postcode in label',
      () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['type'], 'municipality');
      return response([
        address('Paris 1er Arrondissement', 2.335987, 48.862351,
            type: 'municipality')
      ]);
    });
    addTearDown(client.close);
    final places =
        await ProspectLocationService(client: client).search('75001');
    expect(places.single.label, 'Paris 1er Arrondissement (75001)');
  });
  test('invalid coordinates and duplicates do not become selectable addresses',
      () async {
    final valid = address('Paris', 2.33, 48.86);
    final client = MockClient((_) async => response([
          valid,
          valid,
          address('Invalid', 181, 48),
          address('Invalid latitude', 2, 91),
          address('Null island', 0, 0),
          {
            'properties': {'label': 'Bad'},
            'geometry': {
              'type': 'Point',
              'coordinates': ['2', '48']
            }
          }
        ]));
    addTearDown(client.close);
    expect(
        (await ProspectLocationService(client: client).search('Paris')).length,
        1);
  });
  test('same concurrent or cached query makes one network request', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final client = MockClient((_) {
      calls++;
      return pending.future;
    });
    addTearDown(client.close);
    final service = ProspectLocationService(client: client);
    final a = service.search('Paris');
    final b = service.search('PARIS');
    pending.complete(response([address('Paris', 2.33, 48.86)]));
    await Future.wait([a, b]);
    await service.search(' Paris ');
    expect(calls, 1);
  });
  test('network failure is an error, while a successful empty search is empty',
      () async {
    final failed = MockClient((_) async => http.Response('unavailable', 503));
    addTearDown(failed.close);
    await expectLater(ProspectLocationService(client: failed).search('Paris'),
        throwsA(isA<ProspectLocationException>()));
    final empty = MockClient((_) async => response([]));
    addTearDown(empty.close);
    expect(
        await ProspectLocationService(client: empty).search('Paris'), isEmpty);
  });
  test('GPS denial or disabled service never reads coordinates', () async {
    final denied = TestLocation()..permission = PermissionStatus.denied;
    await expectLater(ProspectDeviceLocation(location: denied).current(),
        throwsA(isA<ProspectLocationException>()));
    expect(denied.reads, 0);
    expect(denied.permissionRequests, 1);
    final disabled = TestLocation()..enabled = false;
    await expectLater(ProspectDeviceLocation(location: disabled).current(),
        throwsA(isA<ProspectLocationException>()));
    expect(disabled.reads, 0);
  });
  test('granted GPS supplies a centre without an address network request',
      () async {
    final device = TestLocation();
    final centre = await ProspectDeviceLocation(location: device).current();
    expect(centre.devicePosition, isTrue);
    expect(centre.lat, 48.86);
    expect(centre.lon, 2.33);
    expect(device.reads, 1);
  });
}
