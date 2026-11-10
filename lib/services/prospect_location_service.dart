import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';

class ProspectLocationException implements Exception {
  final String message;
  const ProspectLocationException(this.message);
  @override
  String toString() => message;
}

/// A centre explicitly chosen by the user, not an establishment's location.
class ProspectSearchLocation {
  final String label;
  final double lat, lon;
  final String kind;
  final double? accuracyMeters;
  const ProspectSearchLocation(
      {required this.label,
      required this.lat,
      required this.lon,
      this.kind = 'address',
      this.accuracyMeters});
  bool get devicePosition => kind == 'device';
  bool get preciseAddress => kind == 'housenumber';
}

class ProspectLocationService {
  static final _sharedClient = http.Client();
  final http.Client _client;
  final Map<String, (DateTime, List<ProspectSearchLocation>)> _cache = {};
  final Map<String, Future<List<ProspectSearchLocation>>> _pending = {};
  ProspectLocationService({http.Client? client})
      : _client = client ?? _sharedClient;

  static Uri searchUri(String query) {
    final text = query.trim();
    return Uri.https('data.geopf.fr', '/geocodage/search', {
      'q': text,
      'limit': '6',
      'index': 'address',
      if (RegExp(r'^\d{5}$').hasMatch(text)) 'type': 'municipality',
    });
  }

  /// Explicit button/submit only: typing does not trigger network requests.
  Future<List<ProspectSearchLocation>> search(String query) async {
    final text = query.trim();
    if (text.length < 3 || text.length > 240) {
      throw const ProspectLocationException(
          'Saisissez une rue, une ville ou un code postal.');
    }
    final key = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(hours: 1)) {
      return cached.$2;
    }
    final inFlight = _pending[key];
    if (inFlight != null) return inFlight;
    final future = _lookup(text, key);
    _pending[key] = future;
    try {
      return await future;
    } finally {
      _pending.remove(key);
    }
  }

  Future<List<ProspectSearchLocation>> _lookup(String query, String key) async {
    try {
      final response = await _client.get(searchUri(query), headers: {
        'Accept': 'application/json',
        'User-Agent': 'Prospecto/1.6 (contact: contact@digitalsolutionsai.com)',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const ProspectLocationException(
            'Le service d’adresses est indisponible. Réessayez ou utilisez votre position.');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map || body['features'] is! List) {
        throw const ProspectLocationException(
            'Réponse du service d’adresses invalide.');
      }
      final rows = <ProspectSearchLocation>[];
      final seen = <String>{};
      for (final entry in (body['features'] as List).take(20)) {
        if (entry is! Map ||
            entry['properties'] is! Map ||
            entry['geometry'] is! Map) {
          continue;
        }
        final properties = entry['properties'] as Map;
        final geometry = entry['geometry'] as Map;
        final coordinates = geometry['coordinates'];
        if (geometry['type'] != 'Point' ||
            coordinates is! List ||
            coordinates.length < 2) {
          continue;
        }
        final lon = coordinates[0] is num
            ? (coordinates[0] as num).toDouble()
            : double.nan;
        final lat = coordinates[1] is num
            ? (coordinates[1] as num).toDouble()
            : double.nan;
        if (!_validCoordinates(lat, lon)) continue;
        var label = '${properties['label'] ?? ''}'.trim();
        if (label.isEmpty) continue;
        final postcode = '${properties['postcode'] ?? ''}'.trim();
        if (postcode.isNotEmpty && !label.contains(postcode)) {
          label = '$label ($postcode)';
        }
        if (!seen.add('$label|$lat|$lon')) continue;
        rows.add(ProspectSearchLocation(
            label: label,
            lat: lat,
            lon: lon,
            kind: '${properties['type'] ?? 'address'}'));
        if (rows.length == 6) break;
      }
      final result = List<ProspectSearchLocation>.unmodifiable(rows);
      if (_cache.length >= 32) _cache.remove(_cache.keys.first);
      _cache[key] = (DateTime.now(), result);
      return result;
    } on ProspectLocationException {
      rethrow;
    } on TimeoutException {
      throw const ProspectLocationException(
          'La recherche d’adresse prend trop de temps. Réessayez ou utilisez votre position.');
    } catch (_) {
      throw const ProspectLocationException(
          'Connexion au service d’adresses impossible. Votre position GPS peut servir de centre.');
    }
  }
}

bool _validCoordinates(double lat, double lon) =>
    lat.isFinite &&
    lon.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lon >= -180 &&
    lon <= 180 &&
    !(lat == 0 && lon == 0);

class ProspectDeviceLocation {
  final Location _location;
  ProspectDeviceLocation({Location? location})
      : _location = location ?? Location();
  Future<ProspectSearchLocation> current() async {
    var enabled = await _location.serviceEnabled();
    if (!enabled) enabled = await _location.requestService();
    if (!enabled) {
      throw const ProspectLocationException(
          'Activez la localisation ou saisissez une adresse.');
    }
    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      throw const ProspectLocationException(
          'Localisation refusée. Vous pouvez saisir une adresse ou un code postal.');
    }
    final data =
        await _location.getLocation().timeout(const Duration(seconds: 20));
    final lat = data.latitude, lon = data.longitude;
    if (lat == null || lon == null || !_validCoordinates(lat, lon)) {
      throw const ProspectLocationException(
          'Position indisponible. Réessayez ou saisissez une adresse.');
    }
    return ProspectSearchLocation(
        label: 'Ma position',
        lat: lat,
        lon: lon,
        kind: 'device',
        accuracyMeters: data.accuracy);
  }
}
