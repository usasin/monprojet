import 'dart:async';
import 'dart:math' as math;

import 'french_registry_service.dart';
import 'osm_search_service.dart';
import 'prospecto_directory_api.dart';

typedef DirectoryOsmSearch = Future<List<OSMPlace>> Function({
  required double lat,
  required double lng,
  required int radiusMeters,
  required String query,
  required String languageCode,
});

typedef DirectoryRegistrySearch = Future<List<OSMPlace>> Function({
  required double lat,
  required double lng,
  required int radiusMeters,
  required String query,
});

class DirectoryOnlineSearchException implements Exception {
  final List<String> failedSources;
  const DirectoryOnlineSearchException(this.failedSources);

  @override
  String toString() => 'Recherche en ligne indisponible ou incomplète '
      '(${failedSources.join(', ')}). Réessayez avec une connexion ; '
      'cela ne signifie pas qu’il n’y a aucun établissement dans cette zone.';
}

class DirectoryOnlineSearchResult {
  final List<OSMPlace> places;
  final List<String> failedSources;

  DirectoryOnlineSearchResult(
    List<OSMPlace> places, {
    List<String> failedSources = const [],
    this.coveragePartial = false,
    this.notice = '',
  })  : places = List.unmodifiable(places),
        failedSources = List.unmodifiable(failedSources);

  final bool coveragePartial;
  final String notice;
  bool get partial => failedSources.isNotEmpty || coveragePartial;
}

/// Online fallback independent of Firebase. A slow or unavailable provider must
/// not discard results returned by the other provider, or look like zero matches.
class DirectoryOnlineSearch {
  static const _osmSource = 'OpenStreetMap';
  static const _registrySource = 'Annuaire des Entreprises';

  final DirectoryOsmSearch _osmSearch;
  final DirectoryRegistrySearch _registrySearch;
  final Duration timeout;
  final ProspectoDirectoryApi? _api;

  DirectoryOnlineSearch({
    DirectoryOsmSearch? osmSearch,
    DirectoryRegistrySearch? registrySearch,
    ProspectoDirectoryApi? api,
    this.timeout = const Duration(seconds: 20),
  })  : _api = api ?? ProspectoDirectoryApi.configured(),
        _osmSearch = osmSearch ?? OSMSearchService().searchNearby,
        _registrySearch =
            registrySearch ?? FrenchRegistryService().searchNearby;

  Future<List<OSMPlace>> search({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    String languageCode = 'fr',
  }) async =>
      (await searchDetailed(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        query: query,
        languageCode: languageCode,
      ))
          .places;

  Future<DirectoryOnlineSearchResult> searchDetailed({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    String languageCode = 'fr',
  }) async {
    if (_api != null) {
      final result = await _api
          .searchNearby(
              lat: lat, lng: lng, radiusMeters: radiusMeters, query: query)
          .timeout(timeout);
      return DirectoryOnlineSearchResult(result.places,
          coveragePartial: result.partial, notice: result.notice);
    }
    final requests = <Future<_ProviderResult>>[
      _request(
          _osmSource,
          () => _osmSearch(
                lat: lat,
                lng: lng,
                radiusMeters: radiusMeters,
                query: query,
                languageCode: languageCode,
              )),
    ];
    if (FrenchRegistryService.supportsLocation(lat, lng) &&
        FrenchRegistryService.nafCodesFor(query) != null) {
      requests.add(_request(
          _registrySource,
          () => _registrySearch(
                lat: lat,
                lng: lng,
                radiusMeters: radiusMeters,
                query: query,
              )));
    }
    // Requests start before awaiting either one. Each shares the same bounded
    // wait; a provider that finishes after its deadline cannot alter the result.
    final outcomes = await Future.wait(requests);
    final failed = [
      for (final result in outcomes)
        if (result.failed) result.source
    ];
    final places = <OSMPlace>[];
    for (final result in outcomes) {
      for (final raw in result.places) {
        final place = _withSource(raw, result.source);
        final duplicate =
            places.indexWhere((existing) => _same(existing, place));
        if (duplicate < 0) {
          places.add(place);
        } else {
          places[duplicate] = _merge(places[duplicate], place);
        }
      }
    }
    if (places.isEmpty && failed.isNotEmpty) {
      throw DirectoryOnlineSearchException(List.unmodifiable(failed));
    }
    places.sort((a, b) => _distance(lat, lng, a.lat, a.lng)
        .compareTo(_distance(lat, lng, b.lat, b.lng)));
    return DirectoryOnlineSearchResult(places, failedSources: failed);
  }

  Future<_ProviderResult> _request(
    String source,
    Future<List<OSMPlace>> Function() request,
  ) async {
    try {
      final places = await Future.sync(request).timeout(timeout);
      return _ProviderResult(source, places);
    } catch (_) {
      return _ProviderResult(source, const [], failed: true);
    }
  }

  static bool _same(OSMPlace first, OSMPlace second) {
    if (first.id == second.id) return true;
    final a = _siret(first), b = _siret(second);
    if (a != null && b != null) return a == b;
    final name = _name(first.name);
    return name.isNotEmpty &&
        name == _name(second.name) &&
        _distance(first.lat, first.lng, second.lat, second.lng) <= 35;
  }

  static String? _siret(OSMPlace place) {
    final explicit = place.siret?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return RegExp(r'^siret[:_](\d{14})$').firstMatch(place.id)?.group(1);
  }

  static String _name(String value) {
    var normalized = value.toLowerCase().trim();
    const accents = 'àâäéèêëîïôöùûüç';
    const ascii = 'aaaeeeeiioouuuc';
    for (var i = 0; i < accents.length; i++) {
      normalized = normalized.replaceAll(accents[i], ascii[i]);
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static String? _prefer(String? first, String? second) =>
      first != null && first.trim().isNotEmpty ? first : second;

  static OSMPlace _withSource(OSMPlace value, String source) =>
      _copy(value, source: _prefer(value.source, source));

  static OSMPlace _merge(OSMPlace first, OSMPlace second) {
    final sources = <String>{
      if (first.source?.isNotEmpty == true) first.source!,
      if (second.source?.isNotEmpty == true) second.source!,
    };
    return OSMPlace(
      id: first.id,
      name: first.name.isEmpty ? second.name : first.name,
      address: first.address.isEmpty ? second.address : first.address,
      lat: first.lat,
      lng: first.lng,
      category: first.category.isEmpty ? second.category : first.category,
      phone: _prefer(first.phone, second.phone),
      email: _prefer(first.email, second.email),
      website: _prefer(first.website, second.website),
      openingHours: _prefer(first.openingHours, second.openingHours),
      instagram: _prefer(first.instagram, second.instagram),
      facebook: _prefer(first.facebook, second.facebook),
      linkedin: _prefer(first.linkedin, second.linkedin),
      source: sources.isEmpty ? null : sources.join(' + '),
      siret: _siret(first) ?? _siret(second),
      nafCode: _prefer(first.nafCode, second.nafCode),
    );
  }

  static OSMPlace _copy(OSMPlace value, {String? source}) => OSMPlace(
        id: value.id,
        name: value.name,
        address: value.address,
        lat: value.lat,
        lng: value.lng,
        category: value.category,
        phone: value.phone,
        email: value.email,
        website: value.website,
        openingHours: value.openingHours,
        instagram: value.instagram,
        facebook: value.facebook,
        linkedin: value.linkedin,
        source: source,
        siret: value.siret,
        nafCode: value.nafCode,
      );

  static double _distance(
      double lat, double lng, double otherLat, double otherLng) {
    final dlat = (otherLat - lat) * math.pi / 180;
    final dlon = (otherLng - lng) * math.pi / 180;
    final h = math.pow(math.sin(dlat / 2), 2) +
        math.cos(lat * math.pi / 180) *
            math.cos(otherLat * math.pi / 180) *
            math.pow(math.sin(dlon / 2), 2);
    return 2 * 6371008.8 * math.asin(math.sqrt(h.clamp(0, 1)));
  }
}

class _ProviderResult {
  final String source;
  final List<OSMPlace> places;
  final bool failed;
  const _ProviderResult(this.source, this.places, {this.failed = false});
}
