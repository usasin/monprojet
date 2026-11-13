import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../directory/directory_models.dart';
import 'osm_search_service.dart';

class ProspectoApiSearchResult {
  final List<OSMPlace> places;
  final bool partial;
  final String notice;
  const ProspectoApiSearchResult(this.places,
      {required this.partial, required this.notice});
}

/// Prospecto's own verified directory. No external registry proxy or fallback.
class ProspectoDirectoryApi {
  static const configuredUrl =
      String.fromEnvironment('PROSPECTO_DIRECTORY_API_URL');
  static final _sharedHttp = http.Client();
  final Uri origin;
  final http.Client _http;
  final Duration timeout;
  DateTime? _retryAfter;

  ProspectoDirectoryApi(String url,
      {http.Client? client, this.timeout = const Duration(seconds: 8)})
      : origin = _origin(url),
        _http = client ?? _sharedHttp;

  static ProspectoDirectoryApi? configured() => configuredUrl.trim().isEmpty
      ? null
      : ProspectoDirectoryApi(configuredUrl);

  static Uri _origin(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const DirectoryException(
          'Adresse HTTPS du serveur Prospecto invalide.');
    }
    return uri.replace(path: '/');
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? query]) async {
    if (_retryAfter?.isAfter(DateTime.now()) == true) {
      throw const DirectoryException(
          'Serveur occupé. Réessayez dans quelques instants.');
    }
    final request = http.Request(
        'GET', origin.resolve(path).replace(queryParameters: query))
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    return (() async {
      final response = await _http.send(request);
      if (response.statusCode != 200) {
        if (response.statusCode == 429) {
          final seconds =
              int.tryParse(response.headers['retry-after'] ?? '') ?? 2;
          _retryAfter =
              DateTime.now().add(Duration(seconds: seconds.clamp(1, 60)));
        }
        await response.stream.listen((_) {}).cancel();
        throw const DirectoryException(
            'Annuaire Prospecto indisponible. Réessayez avec une connexion.');
      }
      const maxBytes = 4 * 1024 * 1024;
      if ((response.contentLength ?? 0) > maxBytes) {
        await response.stream.listen((_) {}).cancel();
        throw const FormatException('Réponse annuaire trop volumineuse.');
      }
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Réponse annuaire trop volumineuse.');
        }
        bytes.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Réponse annuaire invalide.');
      }
      return decoded;
    })()
        .timeout(timeout);
  }

  Future<List<DirectoryPack>> catalog() async {
    final packs =
        parseDirectoryCatalog(await _get('/v1/catalog'), base: origin);
    for (final pack in packs) {
      final uri = pack.url;
      if (pack.demo ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.origin != origin.origin ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !uri.path.startsWith('/v1/packs/')) {
        throw const FormatException(
            'Téléchargement hors du serveur Prospecto.');
      }
    }
    return packs;
  }

  Future<ProspectoApiSearchResult> searchNearby(
      {required double lat,
      required double lng,
      required int radiusMeters,
      required String query}) async {
    if (!lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        radiusMeters < 100 ||
        radiusMeters > 50000) {
      throw const DirectoryException('Lieu ou rayon invalide.');
    }
    final places = <OSMPlace>[];
    final seen = <String>{};
    var partial = false;
    var notice = '';
    String? version;
    // Keep mobile searches bounded. The response explicitly reports a limit.
    for (var page = 1; page <= 5; page++) {
      final data = await _get('/v1/search', {
        'lat': '$lat',
        'lon': '$lng',
        'radius_m': '$radiusMeters',
        'activities': query.trim(),
        'page': '$page',
        'page_size': '100',
      });
      if (data['results'] is! List ||
          data['pagination'] is! Map ||
          data['coverage'] is! Map ||
          data['version'] is! String) {
        throw const FormatException('Recherche annuaire invalide.');
      }
      if (version != null && version != data['version']) {
        throw const DirectoryException(
            'Annuaire mis à jour. Relancez la recherche.');
      }
      version = data['version'] as String;
      partial |= (data['coverage'] as Map)['complete'] != true;
      notice = data['notice'] is String ? data['notice'] as String : '';
      final rows = data['results'] as List;
      if (rows.length > 100) {
        throw const FormatException('Page annuaire trop longue.');
      }
      for (final raw in rows) {
        if (raw is! Map) throw const FormatException('Établissement invalide.');
        final a = raw['lat'], b = raw['lon'];
        final siret = raw['siret'];
        final rawId = raw['id'];
        if (a is! num ||
            b is! num ||
            !a.isFinite ||
            !b.isFinite ||
            a.abs() > 90 ||
            b.abs() > 180 ||
            rawId is! String ||
            rawId.isEmpty ||
            rawId.length > 200 ||
            (siret != null &&
                (siret is! String || !RegExp(r'^\d{14}$').hasMatch(siret))) ||
            raw['name'] is! String ||
            (raw['name'] as String).trim().isEmpty ||
            raw['address'] is! String) {
          throw const FormatException('Établissement annuaire invalide.');
        }
        final h = math.pow(math.sin((a - lat) * math.pi / 360), 2) +
            math.cos(lat * math.pi / 180) *
                math.cos(a * math.pi / 180) *
                math.pow(math.sin((b - lng) * math.pi / 360), 2);
        final distance = 12742000 * math.asin(math.sqrt(h.clamp(0, 1)));
        if (distance > radiusMeters + 0.1) {
          throw const FormatException('Établissement hors du rayon demandé.');
        }
        final id = siret == null ? rawId : 'siret_$siret';
        if (!seen.add(id)) continue;
        places.add(OSMPlace(
            id: id,
            name: raw['name'] as String,
            address: raw['address'] as String,
            lat: a.toDouble(),
            lng: b.toDouble(),
            category: raw['naf_code']?.toString() ?? 'Entreprise',
            source:
                'Annuaire Prospecto · ${raw['source'] ?? 'source publique'}',
            siret: siret as String?,
            nafCode: raw['naf_code']?.toString()));
      }
      final pagination = data['pagination'] as Map;
      if (pagination['page'] != page || pagination['page_size'] != 100) {
        throw const FormatException('Pagination annuaire incohérente.');
      }
      final next = pagination['next_page'];
      if (next == null) break;
      if (next != page + 1 || rows.isEmpty) {
        throw const FormatException('Pagination annuaire incohérente.');
      }
      if (page == 5) {
        partial = true;
        notice =
            '$notice Limite de 500 résultats affichés : réduisez le rayon ou précisez les activités.';
      }
    }
    return ProspectoApiSearchResult(List.unmodifiable(places),
        partial: partial,
        notice: notice.isNotEmpty
            ? notice
            : partial
                ? 'Couverture partielle de l’annuaire Prospecto.'
                : '');
  }
}
