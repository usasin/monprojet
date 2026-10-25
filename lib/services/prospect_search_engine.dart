// Recherche resilientielle : OSM mondial + registre officiel francais.
// Une source disponible peut afficher ses resultats sans attendre celle qui
// est en panne. Les caches ne melangent jamais deux zones ou activites.
import 'dart:async';
import 'dart:math';

import 'french_registry_service.dart';
import 'osm_search_service.dart';
import 'prospect_search_config_service.dart';

class ProspectSearchEngine {
  final OSMSearchService _osm = OSMSearchService();
  final FrenchRegistryService _registry = FrenchRegistryService();

  static final Map<String, _SearchCacheEntry> _cache = {};
  static final Map<String, Future<List<OSMPlace>>> _inFlight = {};
  static const _cacheTtl = Duration(minutes: 10);
  static const _staleTtl = Duration(hours: 1);
  static const _maxEntries = 40;

  Future<List<OSMPlace>> searchNearby({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    String languageCode = 'fr',
  }) async {
    final config = await ProspectSearchConfigService.instance.load();
    final key =
        '${lat.toStringAsFixed(5)}|${lng.toStringAsFixed(5)}|$radiusMeters|${query.trim().toLowerCase()}|${config.toMap()}';
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.savedAt) < _cacheTtl) {
      return cached.places;
    }
    if (_inFlight.containsKey(key)) return _inFlight[key]!;

    final future = _search(
      lat: lat, lng: lng, radiusMeters: radiusMeters,
      query: query, languageCode: languageCode, config: config,
      stale: cached,
      cacheKey: key,
    );
    _inFlight[key] = future;
    try {
      final places = await future;
      if (places.isNotEmpty) {
        _cache.remove(key);
        _cache[key] = _SearchCacheEntry(places, DateTime.now());
        while (_cache.length > _maxEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
      return places;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  Future<List<OSMPlace>> _search({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    required String languageCode,
    required ProspectSearchConfig config,
    required _SearchCacheEntry? stale,
    required String cacheKey,
  }) async {
    if (!config.overpassEnabled && !config.registryEnabled) {
      throw StateError('Toutes les sources de recherche sont desactivees.');
    }
    var osm = <OSMPlace>[];
    var registry = <OSMPlace>[];
    var failed = 0;
    var completed = 0;
    final tasks = <Future<void>>[];
    final earlyResults = Completer<void>();

    if (config.overpassEnabled) {
      tasks.add(_osm.searchNearby(
        lat: lat, lng: lng, query: query,
        radiusMeters: radiusMeters, languageCode: languageCode,
        expandedRestaurants: config.expandedRestaurants,
      ).then((places) {
        osm = places;
        completed++;
        if (places.isNotEmpty && !earlyResults.isCompleted) {
          earlyResults.complete();
        }
      }).catchError((Object _) {
        failed++;
        completed++;
      }));
    }

    if (config.registryEnabled && FrenchRegistryService.supportsLocation(lat, lng) &&
        FrenchRegistryService.nafCodesFor(query) != null) {
      tasks.add(_registry.searchNearby(
        lat: lat, lng: lng, query: query,
        radiusMeters: radiusMeters, languageCode: languageCode,
      ).then((places) {
        registry = places;
        completed++;
        if (places.isNotEmpty && !earlyResults.isCompleted) {
          earlyResults.complete();
        }
      }).catchError((Object _) {
        failed++;
        completed++;
      }));
    }

    if (tasks.isEmpty) return const [];
    final allDone = Future.wait<void>(tasks);
    // Les donnees de la source plus lente enrichiront le cache pour la
    // prochaine recherche identique, sans retarder l'affichage actuel.
    allDone.then((_) {
      final complete = _merge(lat, lng, osm, registry);
      if (complete.isNotEmpty) {
        _cache.remove(cacheKey);
        _cache[cacheKey] = _SearchCacheEntry(complete, DateTime.now());
        while (_cache.length > _maxEntries) {
          _cache.remove(_cache.keys.first);
        }
      }
    });
    // Une premiere source avec des resultats libere l'ecran apres une courte
    // marge pour obtenir les enrichissements de la seconde. Au plus 14s.
    await Future.any<void>([
      allDone.then<void>((_) {}),
      earlyResults.future.then<void>((_) =>
          Future<void>.delayed(const Duration(milliseconds: 1400))),
      Future<void>.delayed(const Duration(seconds: 14)),
    ]);

    final merged = _merge(lat, lng, osm, registry);
    if (merged.isEmpty && failed > 0 &&
        stale != null && DateTime.now().difference(stale.savedAt) < _staleTtl) {
      return stale.places;
    }
    if (merged.isEmpty && completed < tasks.length) {
      throw TimeoutException('Recherche indisponible : delai depasse.');
    }
    if (merged.isEmpty && completed == failed && completed > 0) {
      throw StateError('Les sources de recherche sont indisponibles.');
    }
    return merged;
  }

  static List<OSMPlace> _merge(double lat, double lng,
      List<OSMPlace> osm, List<OSMPlace> registry) {
    final merged = <OSMPlace>[...osm];
    for (final place in registry) {
      final matched = merged.indexWhere((existing) {
        if (_distance(existing.lat, existing.lng, place.lat, place.lng) > 35) {
          return false;
        }
        final a = _normalized(existing.name);
        final b = _normalized(place.name);
        return a.isNotEmpty && b.isNotEmpty &&
            (a == b || (a.length > 6 && b.contains(a)) ||
                (b.length > 6 && a.contains(b)));
      });
      if (matched < 0) {
        merged.add(place);
      } else {
        // Conserver les contacts OSM, enrichir uniquement l'identite legale.
        final old = merged[matched];
        merged[matched] = OSMPlace(
          id: old.id, name: old.name, address: old.address,
          lat: old.lat, lng: old.lng, category: old.category,
          phone: old.phone, email: old.email, website: old.website,
          openingHours: old.openingHours, instagram: old.instagram,
          facebook: old.facebook, linkedin: old.linkedin,
          cuisine: old.cuisine, description: old.description,
          source: 'OSM + Annuaire FR',
          siret: place.siret, nafCode: place.nafCode,
        );
      }
    }
    merged.sort((a, b) => _distance(lat, lng, a.lat, a.lng)
        .compareTo(_distance(lat, lng, b.lat, b.lng)));

    return merged;
  }

  static String _normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static double _distance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dp = (lat2 - lat1) * pi / 180;
    final dl = (lon2 - lon1) * pi / 180;
    final a = sin(dp / 2) * sin(dp / 2) +
        cos(p1) * cos(lat2 * pi / 180) * sin(dl / 2) * sin(dl / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class _SearchCacheEntry {
  const _SearchCacheEntry(this.places, this.savedAt);
  final List<OSMPlace> places;
  final DateTime savedAt;
}
