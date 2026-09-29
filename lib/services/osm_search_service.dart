// lib/services/osm_search_service.dart
// Recherche gratuite via OpenStreetMap (Nominatim + Overpass)
// Objectif: une recherche "terrain" fiable
// - Rayon strict (ex: 2km = 2km)
// - Champ texte utile (coiffeur, restaurant, b2b, chantier, ...)
// - Mode vide = "Tout (pro)" (pas de bus / arrêts)

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class OSMGeoPoint {
  final double lat;
  final double lng;
  OSMGeoPoint(this.lat, this.lng);
}

class OSMPlace {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;

  final String? phone;
  final String? email;
  final String? website;
  final String? openingHours;
  final String? instagram;
  final String? facebook;
  final String? linkedin;

  OSMPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    this.phone,
    this.email,
    this.website,
    this.openingHours,
    this.instagram,
    this.facebook,
    this.linkedin,
  });
}

class _TimedCacheEntry<T> {
  final T value;
  final DateTime storedAt;

  const _TimedCacheEntry(this.value, this.storedAt);
}

class OSMSearchService {
  static const _nominatim = 'https://nominatim.openstreetmap.org/search';
  static const _overpassEndpoints = <String>[
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  static const Map<String, String> _headers = {
    'User-Agent':
        'Prospecto/1.3.11 (contact: contact@digitalsolutionsai.com)',
    'Accept': 'application/json',
  };

  // Connexion HTTP partagée : évite de recréer une socket/TLS à chaque recherche.
  static final http.Client _client = http.Client();

  // Caches partagés entre les écrans. Ils sont volontairement bornés et avec
  // TTL pour accélérer les recherches répétées sans conserver des données
  // indéfiniment en mémoire.
  static final Map<String, _TimedCacheEntry<OSMGeoPoint>> _geocodeCache = {};
  static final Map<String, _TimedCacheEntry<List<OSMPlace>>> _nearbyCache = {};
  static final Map<String, Future<OSMGeoPoint>> _geocodeInFlight = {};
  static final Map<String, Future<List<OSMPlace>>> _nearbyInFlight = {};
  static final Map<String, DateTime> _endpointRetryAfter = {};

  static const Duration _geocodeTtl = Duration(hours: 1);
  static const Duration _geocodeStaleFallback = Duration(hours: 24);
  static const Duration _nearbyTtl = Duration(minutes: 5);
  static const Duration _nearbyStaleFallback = Duration(minutes: 30);
  static const Duration _endpointCooldown = Duration(seconds: 75);
  static const int _maxGeocodeCacheEntries = 80;
  static const int _maxNearbyCacheEntries = 40;

  /// Géocode une adresse dans le monde entier via Nominatim.
  ///
  /// Le pays n'est volontairement pas forcé. L'utilisateur peut saisir une
  /// adresse en France, au Royaume-Uni, aux États-Unis ou dans un autre pays.
  /// Pour les adresses ambiguës, il est recommandé d'ajouter la ville et le
  /// pays dans le champ de recherche.
  Future<OSMGeoPoint> geocode(
    String address, {
    String languageCode = 'en',
  }) async {
    final normalizedLanguage = languageCode.trim().toLowerCase();
    final key = '${address.trim().toLowerCase()}|$normalizedLanguage';
    final now = DateTime.now();
    final cached = _geocodeCache[key];
    if (cached != null && now.difference(cached.storedAt) < _geocodeTtl) {
      _touchCacheEntry(_geocodeCache, key, cached);
      return cached.value;
    }

    // Deux clics rapides ou deux écrans demandant la même adresse partagent
    // la même requête au lieu de solliciter Nominatim plusieurs fois.
    final inFlight = _geocodeInFlight[key];
    if (inFlight != null) return inFlight;

    final request = _performGeocode(
      address: address,
      languageCode: normalizedLanguage,
      key: key,
      stale: cached,
    );
    _geocodeInFlight[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_geocodeInFlight[key], request)) {
        _geocodeInFlight.remove(key);
      }
    }
  }

  Future<OSMGeoPoint> _performGeocode({
    required String address,
    required String languageCode,
    required String key,
    required _TimedCacheEntry<OSMGeoPoint>? stale,
  }) async {
    final uri = buildGeocodeUri(
      address: address,
      languageCode: languageCode,
    );

    try {
      final res = await _getWithRetry(uri);
      if (res.statusCode != 200) {
        throw Exception('Géocodage échoué (HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! List) {
        throw Exception('Géocodage échoué: réponse invalide');
      }
      if (decoded.isEmpty) {
        throw Exception('Géocodage échoué: adresse introuvable');
      }

      final item = decoded.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
      if (lat == 0.0 && lon == 0.0) {
        throw Exception('Géocodage échoué: coordonnées invalides');
      }

      final gp = OSMGeoPoint(lat, lon);
      _putBoundedCache(
        _geocodeCache,
        key,
        _TimedCacheEntry(gp, DateTime.now()),
        _maxGeocodeCacheEntries,
      );
      return gp;
    } catch (_) {
      if (stale != null &&
          DateTime.now().difference(stale.storedAt) < _geocodeStaleFallback) {
        return stale.value;
      }
      rethrow;
    }
  }

  /// Exposé pour les tests de configuration sans effectuer d'appel réseau.
  static Uri buildGeocodeUri({
    required String address,
    String languageCode = 'en',
  }) {
    final language = languageCode.trim().isEmpty ? 'en' : languageCode.trim();
    return Uri.parse(_nominatim).replace(queryParameters: {
      'q': address.trim(),
      'format': 'json',
      'limit': '1',
      'addressdetails': '1',
      'accept-language': language,
      'dedupe': '1',
      'email': 'contact@digitalsolutionsai.com',
    });
  }

  /// Recherche des lieux autour d'un point.
  /// - query vide => "Tout (pro)" (pas de bus/arrêts)
  /// - query texte => mapping tags + fallback nom (dans le pro uniquement)
  Future<List<OSMPlace>> searchNearby({
    required double lat,
    required double lng,
    required String query,
    required int radiusMeters,
    String languageCode = 'en',
  }) async {
    final q = query.trim();
    final cacheKey =
        '${lat.toStringAsFixed(5)}|${lng.toStringAsFixed(5)}|$radiusMeters|${q.toLowerCase()}|${languageCode.toLowerCase()}';
    final now = DateTime.now();
    final cached = _nearbyCache[cacheKey];
    if (cached != null && now.difference(cached.storedAt) < _nearbyTtl) {
      _touchCacheEntry(_nearbyCache, cacheKey, cached);
      return cached.value;
    }

    final inFlight = _nearbyInFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final request = _performNearbySearch(
      lat: lat,
      lng: lng,
      query: q,
      radiusMeters: radiusMeters,
      languageCode: languageCode,
      cacheKey: cacheKey,
      stale: cached,
    );
    _nearbyInFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_nearbyInFlight[cacheKey], request)) {
        _nearbyInFlight.remove(cacheKey);
      }
    }
  }

  Future<List<OSMPlace>> _performNearbySearch({
    required double lat,
    required double lng,
    required String query,
    required int radiusMeters,
    required String languageCode,
    required String cacheKey,
    required _TimedCacheEntry<List<OSMPlace>>? stale,
  }) async {
    final tokens = _tokenize(query);
    final overpassQuery = _buildOverpassQuery(
      lat: lat,
      lng: lng,
      radius: radiusMeters,
      tokens: tokens,
    );

    try {
      final res = await _requestOverpass(overpassQuery);
      if (res.statusCode != 200) {
        throw Exception('Recherche échouée (HTTP ${res.statusCode})');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Recherche échouée: réponse OSM invalide');
      }
      final elements = (decoded['elements'] as List?) ?? [];

      final seen = <String>{};
      final out = <OSMPlace>[];

      for (final e in elements) {
        final m = e as Map<String, dynamic>;
        final id = '${m['type']}_${m['id']}';
        if (seen.contains(id)) continue;

        double? elat;
        double? elon;
        if (m['lat'] != null && m['lon'] != null) {
          elat = (m['lat'] as num).toDouble();
          elon = (m['lon'] as num).toDouble();
        } else if (m['center'] != null) {
          elat = (m['center']['lat'] as num).toDouble();
          elon = (m['center']['lon'] as num).toDouble();
        }
        if (elat == null || elon == null) continue;

        // Rayon strict conservé : aucune modification fonctionnelle.
        if (_dist(lat, lng, elat, elon) > radiusMeters.toDouble()) continue;

        final tags = (m['tags'] as Map?)?.cast<String, dynamic>() ?? {};
        final highway = (tags['highway'] ?? '').toString();
        final publicTransport = (tags['public_transport'] ?? '').toString();
        if (highway == 'bus_stop' || publicTransport == 'platform') continue;

        final name =
            (tags['name'] ?? tags['brand'] ?? tags['operator'] ?? '')
                .toString()
                .trim();
        if (name.isEmpty) continue;

        seen.add(id);
        out.add(
          OSMPlace(
            id: id,
            name: name,
            address: _formatAddress(tags),
            lat: elat,
            lng: elon,
            category: _humanCategory(
              tags,
              fallback: query.isEmpty
                  ? (languageCode.startsWith('fr')
                      ? 'Professionnel'
                      : 'Business')
                  : query,
              languageCode: languageCode,
            ),
            phone: _clean(_pickFirst(tags, const ['contact:phone', 'phone'])),
            email: _clean(_pickFirst(tags, const ['contact:email', 'email'])),
            website: _clean(
              _pickFirst(tags, const ['contact:website', 'website', 'url']),
            ),
            openingHours: _clean(_pickFirst(tags, const ['opening_hours'])),
            instagram:
                _clean(_pickFirst(tags, const ['contact:instagram', 'instagram'])),
            facebook:
                _clean(_pickFirst(tags, const ['contact:facebook', 'facebook'])),
            linkedin:
                _clean(_pickFirst(tags, const ['contact:linkedin', 'linkedin'])),
          ),
        );
      }

      // On calcule chaque distance une seule fois au lieu de recalculer la
      // trigonométrie plusieurs fois pendant le tri.
      final distances = <String, double>{
        for (final place in out)
          place.id: _dist(lat, lng, place.lat, place.lng),
      };
      out.sort((a, b) =>
          (distances[a.id] ?? double.infinity)
              .compareTo(distances[b.id] ?? double.infinity));

      _putBoundedCache(
        _nearbyCache,
        cacheKey,
        _TimedCacheEntry(out, DateTime.now()),
        _maxNearbyCacheEntries,
      );
      return out;
    } catch (_) {
      // Si un miroir OSM traverse une panne courte, une recherche identique
      // faite récemment reste utilisable plutôt que de bloquer le commercial.
      if (stale != null &&
          DateTime.now().difference(stale.storedAt) < _nearbyStaleFallback) {
        return stale.value;
      }
      rethrow;
    }
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 22));
        if (response.statusCode == 200) return response;
        lastError = Exception('HTTP ${response.statusCode}');
        if (response.statusCode != 429 && response.statusCode < 500) {
          return response;
        }
      } catch (error) {
        lastError = error;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    throw Exception('Géocodage indisponible: ${lastError ?? 'erreur réseau'}');
  }

  Future<http.Response> _requestOverpass(String overpassQuery) async {
    Object? lastError;
    final now = DateTime.now();

    // Un endpoint qui vient de timeout/429/5xx est temporairement placé en
    // retrait. Les recherches suivantes essaient d'abord les miroirs sains.
    final healthy = <String>[];
    final coolingDown = <String>[];
    for (final endpoint in _overpassEndpoints) {
      final retryAfter = _endpointRetryAfter[endpoint];
      if (retryAfter == null || !retryAfter.isAfter(now)) {
        healthy.add(endpoint);
      } else {
        coolingDown.add(endpoint);
      }
    }
    final endpoints = healthy.isNotEmpty
        ? <String>[...healthy, ...coolingDown]
        : List<String>.from(_overpassEndpoints);

    for (final endpoint in endpoints) {
      final uri = Uri.parse(endpoint);
      try {
        final response = await _client
            .post(
              uri,
              headers: {
                ..._headers,
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
              },
              body: {'data': overpassQuery},
            )
            .timeout(const Duration(seconds: 18));

        if (response.statusCode == 200) {
          _endpointRetryAfter.remove(endpoint);
          return response;
        }

        final details = response.body.trim();
        lastError = Exception(
          'HTTP ${response.statusCode}${details.isEmpty ? '' : ': ${details.substring(0, details.length > 180 ? 180 : details.length)}'}',
        );

        // Une erreur 400 vient de la requête elle-même : un autre miroir
        // donnerait la même réponse. Les 429 et 5xx déclenchent le miroir suivant.
        if (response.statusCode == 400) return response;
        if (response.statusCode == 429 || response.statusCode >= 500) {
          _endpointRetryAfter[endpoint] = DateTime.now().add(_endpointCooldown);
        }
      } catch (error) {
        lastError = error;
        _endpointRetryAfter[endpoint] = DateTime.now().add(_endpointCooldown);
      }
    }

    throw Exception(
      'Recherche OSM temporairement indisponible: ${lastError ?? 'aucune réponse'}',
    );
  }

  static void _touchCacheEntry<T>(
    Map<String, _TimedCacheEntry<T>> cache,
    String key,
    _TimedCacheEntry<T> entry,
  ) {
    cache.remove(key);
    cache[key] = entry;
  }

  static void _putBoundedCache<T>(
    Map<String, _TimedCacheEntry<T>> cache,
    String key,
    _TimedCacheEntry<T> entry,
    int maxEntries,
  ) {
    cache.remove(key);
    cache[key] = entry;
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }

  // ------------------------ Query Builder ------------------------

  List<String> _tokenize(String raw) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const [];

    // support "restaurant, coiffeur, b2b" / "restaurant; coiffeur" / "restaurant|coiffeur"
    final parts = q
        .split(RegExp(r'[,;|\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // garde le nombre raisonnable pour Overpass
    if (parts.length > 6) return parts.sublist(0, 6);
    return parts;
  }

  String _buildOverpassQuery({
    required double lat,
    required double lng,
    required int radius,
    required List<String> tokens,
  }) {
    final clauses = <String>{};

    if (tokens.isEmpty) {
      // ✅ Mode "Tout (pro)" (whitelist)
      clauses.addAll(_businessAllClauses(radius: radius, lat: lat, lng: lng));
    } else {
      for (final t in tokens) {
        final mapped = _mapTokenToTags(t);
        if (mapped.isNotEmpty) {
          for (final tag in mapped) {
            clauses.add('nwr$tag(around:$radius,$lat,$lng);');
          }
        } else {
          // Fallback: recherche texte mais uniquement sur des objets "pro"
          clauses.addAll(_businessTextClauses(radius: radius, lat: lat, lng: lng, text: t));
        }
      }
    }

    return '''
[out:json][timeout:15];
(
${clauses.join('\n')}
);
out center tags qt 500;
''';
  }

  /// Clauses "Tout pro" (évite bus, lieux publics inutiles)
  List<String> _businessAllClauses({required int radius, required double lat, required double lng}) {
    const amenityWhitelist = <String>[
      'restaurant',
      'fast_food',
      'cafe',
      'bar',
      'pharmacy',
      'doctors',
      'dentist',
      'clinic',
      'bank',
      'atm',
      'fuel',
      'car_wash',
      'veterinary',
    ];

    final out = <String>[];

    // shops
    out.add('nwr["shop"](around:$radius,$lat,$lng);');

    // offices
    out.add('nwr["office"](around:$radius,$lat,$lng);');

    // crafts / artisans
    out.add('nwr["craft"](around:$radius,$lat,$lng);');

    // hôtels, santé et activités professionnelles souvent absentes de shop/office
    out.add('nwr["tourism"~"^(hotel|motel|guest_house)\$"](around:$radius,$lat,$lng);');
    out.add('nwr["healthcare"](around:$radius,$lat,$lng);');
    out.add('nwr["industrial"]["name"](around:$radius,$lat,$lng);');
    out.add('nwr["man_made"="works"]["name"](around:$radius,$lat,$lng);');
    out.add('nwr["building"~"^(commercial|retail|industrial|warehouse)\$"]["name"](around:$radius,$lat,$lng);');

    // amenity whitelist
    for (final a in amenityWhitelist) {
      out.add('nwr["amenity"="$a"](around:$radius,$lat,$lng);');
    }

    return out;
  }

  /// Clauses texte mais "pro" uniquement
  List<String> _businessTextClauses({
    required int radius,
    required double lat,
    required double lng,
    required String text,
  }) {
    final safe = _escapeRegex(text);

    return <String>[
      // shop
      'nwr["shop"]["name"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["shop"]["brand"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["shop"]["operator"~"$safe",i](around:$radius,$lat,$lng);',

      // amenity
      'nwr["amenity"]["name"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["amenity"]["brand"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["amenity"]["operator"~"$safe",i](around:$radius,$lat,$lng);',

      // office
      'nwr["office"]["name"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["office"]["brand"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["office"]["operator"~"$safe",i](around:$radius,$lat,$lng);',

      // craft
      'nwr["craft"]["name"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["craft"]["brand"~"$safe",i](around:$radius,$lat,$lng);',
      'nwr["craft"]["operator"~"$safe",i](around:$radius,$lat,$lng);',

      // tourism (hotel)
      'nwr["tourism"]["name"~"$safe",i](around:$radius,$lat,$lng);',
    ];
  }

  /// Mappe un token (texte) vers des tags OSM connus.
  /// Retourne des sélecteurs Overpass du type ["shop"="hairdresser"]
  List<String> _mapTokenToTags(String token) {
    final t = token.trim().toLowerCase();
    if (t.isEmpty) return const [];

    // ---- Coiffure ----
    if (t.contains('coif') ||
        t.contains('barbier') ||
        t.contains('barber') ||
        t.contains('hairdresser') ||
        t.contains('hair salon') ||
        t == 'salon') {
      return const [
        '["shop"="hairdresser"]',
        '["craft"="hairdresser"]',
        '["shop"="barber"]',
      ];
    }

    // ---- Restauration ----
    if (t.contains('resto') ||
        t.contains('restaurant') ||
        t.contains('snack') ||
        t.contains('pizza') ||
        t.contains('kebab') ||
        t.contains('cafe') ||
        t.contains('coffee')) {
      return const [
        '["amenity"="restaurant"]',
        '["amenity"="fast_food"]',
        '["amenity"="cafe"]',
      ];
    }

    // ---- Hôtel ----
    if (t.contains('hotel') || t.contains('hôtel') || t.contains('motel') || t.contains('guest')) {
      return const [
        '["tourism"="hotel"]',
        '["tourism"="motel"]',
        '["tourism"="guest_house"]',
      ];
    }
// ---- Immobilier / agence immobilière ----
    if (t.contains('immob') ||
        t.contains('immobili') ||
        t.contains('estate') ||
        t.contains('real estate') ||
        (t.contains('agence') && t.contains('immo'))) {
      return const [
        r'["office"="estate_agent"]',
      ];
    }
    // ---- Santé ----
    if (t.contains('pharm') ||
        t.contains('doct') ||
        t.contains('médec') ||
        t.contains('medec') ||
        t.contains('dent') ||
        t.contains('clinic') ||
        t.contains('health')) {
      return const [
        '["amenity"="pharmacy"]',
        '["amenity"="doctors"]',
        '["amenity"="dentist"]',
        '["healthcare"="clinic"]',
        '["shop"="optician"]',
      ];
    }

    // ---- Supermarché / alimentation ----
    if (t.contains('boulanger') || t.contains('bakery')) {
      return const ['["shop"="bakery"]'];
    }
    if (t.contains('super') ||
        t.contains('hyper') ||
        t.contains('market') ||
        t.contains('épicer') ||
        t.contains('epicer') ||
        t.contains('grocery') ||
        t.contains('convenience')) {
      return const [
        '["shop"="supermarket"]',
        '["shop"="convenience"]',
        '["shop"="grocery"]',
      ];
    }

    // ---- Auto ----
    if (t.contains('garage') ||
        t.contains('mécan') ||
        t.contains('mecan') ||
        t.contains('auto') ||
        t.contains('car') ||
        t.contains('mechanic') ||
        t.contains('vehicle')) {
      return const [
        '["shop"="car_repair"]',
        '["amenity"="fuel"]',
        '["shop"="car"]',
      ];
    }

    // ---- Banque ----
    if (t.contains('banque') || t.contains('bank') || t.contains('atm') || t.contains('distr')) {
      return const [
        '["amenity"="bank"]',
        '["amenity"="atm"]',
      ];
    }

    // ---- B2B / entreprise ----
    if (t == 'b2b' ||
        t == 'btb' ||
        t.contains('entreprise') ||
        t.contains('soci') ||
        t.contains('industrie') ||
        t.contains('industriel') ||
        t.contains('bureau') ||
        t.contains('office') ||
        t.contains('company') ||
        t.contains('business') ||
        t.contains('warehouse') ||
        t.contains('manufacturer')) {
      return const [
        r'["office"]',
        r'["craft"]',
        r'["industrial"]',
        r'["building"~"^(industrial|warehouse)$"]',
        r'["man_made"="works"]',
      ];
    }



    // ---- Chantier / BTP ----
    if (t.contains('chantier') ||
        t.contains('btp') ||
        t.contains('construction') ||
        t.contains('travaux') ||
        t.contains('builder') ||
        t.contains('contractor') ||
        t.contains('plumber') ||
        t.contains('electrician')) {
      return const [
        r'["landuse"="construction"]',
        r'["building"="construction"]',
        r'["construction"]',
        r'["craft"~"^(builder|construction|plumber|electrician|painter|carpenter|roofer|tiler|glazier|locksmith)$"]',
      ];
    }

    return const [];
  }

  // ------------------------ Helpers ------------------------

  String _escapeRegex(String s) {
    // échappe les caractères regex sensibles pour Overpass
    return s
        .replaceAll('\\', r'\\')
        .replaceAll('.', r'\.')
        .replaceAll('+', r'\+')
        .replaceAll('*', r'\*')
        .replaceAll('?', r'\?')
        .replaceAll('^', r'\^')
        .replaceAll(r'$', r'\$')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('|', r'\|')
        .replaceAll('"', '')
        .replaceAll("'", '');
  }

  String _formatAddress(Map<String, dynamic> tags) {
    final house = (tags['addr:housenumber'] ?? '').toString().trim();
    final street = (tags['addr:street'] ?? tags['addr:place'] ?? '')
        .toString()
        .trim();
    final postcode = (tags['addr:postcode'] ?? '').toString().trim();
    final city = (tags['addr:city'] ??
            tags['addr:town'] ??
            tags['addr:village'] ??
            tags['addr:suburb'] ??
            '')
        .toString()
        .trim();
    final state = (tags['addr:state'] ?? '').toString().trim();
    final country = (tags['addr:country'] ?? '').toString().trim();

    final line1 = [house, street].where((e) => e.isNotEmpty).join(' ').trim();
    final line2 = [city, state, postcode].where((e) => e.isNotEmpty).join(' ').trim();
    final full = [line1, line2, country].where((e) => e.isNotEmpty).join(', ');

    if (full.isNotEmpty) return full;
    final addrFull = (tags['addr:full'] ?? '').toString().trim();
    return addrFull;
  }

  String _humanCategory(
    Map<String, dynamic> tags, {
    required String fallback,
    required String languageCode,
  }) {
    final isFr = languageCode.toLowerCase().startsWith('fr');
    final shop = (tags['shop'] ?? '').toString();
    final amenity = (tags['amenity'] ?? '').toString();
    final tourism = (tags['tourism'] ?? '').toString();
    final office = (tags['office'] ?? '').toString();
    final craft = (tags['craft'] ?? '').toString();
    final healthcare = (tags['healthcare'] ?? '').toString();

    if (shop == 'hairdresser' || craft == 'hairdresser' || shop == 'barber') {
      return isFr ? 'Coiffure' : 'Hair & beauty';
    }
    if (amenity == 'restaurant' || amenity == 'fast_food' || amenity == 'cafe') {
      return isFr ? 'Restauration' : 'Food & drink';
    }
    if (tourism == 'hotel' || tourism == 'motel' || tourism == 'guest_house') {
      return isFr ? 'Hôtel' : 'Hotel';
    }
    if (amenity == 'pharmacy' ||
        amenity == 'doctors' ||
        amenity == 'dentist' ||
        healthcare == 'clinic') {
      return isFr ? 'Santé' : 'Healthcare';
    }
    if (shop == 'car_repair' || amenity == 'fuel') {
      return isFr ? 'Auto' : 'Automotive';
    }
    if (amenity == 'bank' || amenity == 'atm') {
      return isFr ? 'Banque' : 'Banking';
    }
    if (shop.isNotEmpty) return isFr ? 'Commerce' : 'Retail';
    if (office.isNotEmpty) return isFr ? 'Bureaux' : 'Office';
    if (craft.isNotEmpty) return isFr ? 'Artisan' : 'Trades';

    return fallback;
  }

  String? _pickFirst(Map<String, dynamic> tags, List<String> keys) {
    for (final k in keys) {
      final v = tags[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  String? _clean(String? s) {
    if (s == null) return null;
    final x = s.trim();
    return x.isEmpty ? null : x;
  }

  double _dist(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * pi / 180.0;
    final p2 = lat2 * pi / 180.0;
    final dp = (lat2 - lat1) * pi / 180.0;
    final dl = (lon2 - lon1) * pi / 180.0;
    final a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
