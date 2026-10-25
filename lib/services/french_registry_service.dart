// Source publique complementaire pour les entreprises francaises.
// API officielle : https://recherche-entreprises.api.gouv.fr/docs/
// Sans cle API, uniquement donnees publiques et geolocalisees.
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'osm_search_service.dart';

class FrenchRegistryService {
  static final http.Client _client = http.Client();
  static const _url = 'recherche-entreprises.api.gouv.fr';

  static bool supportsLocation(double lat, double lng) =>
      lat >= 41 && lat <= 51.15 && lng >= -5.6 && lng <= 9.8;

  // Retourne les codes NAF applicables ou null si cette activite n'est
  // pas traduisible de maniere fiable en NAF.
  static String? nafCodesFor(String search) {
    // Plusieurs puces de secteurs peuvent etre combinees dans la meme recherche.
    // Ex. 'CHR, GMS' doit rechercher les deux familles NAF, pas aucune.
    final tokens = search.split(RegExp(r'[,;|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(6)
        .toList();
    if (tokens.isEmpty) return '';
    final codes = <String>{};
    var mapped = false;
    for (final token in tokens) {
      final value = _singleNafCodesFor(token);
      if (value == null) continue;
      mapped = true;
      if (value.isEmpty) return '';
      codes.addAll(value.split(',').map((e) => e.trim()));
    }
    return mapped ? codes.join(',') : null;
  }

  static String? _singleNafCodesFor(String search) {
    final query = search.trim().toLowerCase();
    // NAF/APE ne s'applique qu'aux entreprises francaises.
    if (query.isEmpty) return '';
    final explicit = RegExp(r'\b\d{2}\.\d{2}[a-z]\b', caseSensitive: false)
        .firstMatch(query);
    if (explicit != null) return explicit.group(0)!.toUpperCase();

    if (query == 'chr' || query.contains('horeca')) {
      return '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z';
    }
    if (query == 'gms' || query.contains('grande surface') ||
        query.contains('hypermarche') || query.contains('hypermarché') ||
        query.contains('supermarket') || query.contains('hypermarket')) {
      return '47.11D,47.11F';
    }
    if (query.contains('parapharm') || query.contains('drugstore') ||
        query.contains('chemist')) {
      return '47.75Z,47.73Z';
    }
    if (query == 'tpe' || query == 'pme' || query == 'tpe/pme' ||
        query.contains('grand compte') || query.contains('grands comptes') ||
        query.contains('zone d') || query.contains('zone industriel') ||
        query.contains('zone commerciale') ||
        query.contains('business park') || query.contains('industrial park') ||
        query.contains('parc d\'activit')) {
      return ''; // Toutes activites : pas d'invention de NAF universel.
    }
    if (query.contains('logistique') || query.contains('logistics') ||
        query.contains('entrepot') || query.contains('entrepôt') ||
        query.contains('transport')) {
      return '49.41A,49.41B,52.10B,52.29B';
    }
    if (query.contains('resto') ||
        query.contains('restaurant') ||
        query.contains('pizza') ||
        query.contains('snack') ||
        query.contains('kebab') ||
        query.contains('fast food')) {
      return '56.10A,56.10B,56.10C';
    }
    if (query.contains('coif') || query.contains('barbier') ||
        query.contains('barber') || query.contains('hairdresser')) {
      return '96.02A';
    }
    if (query.contains('cafe') || query.contains('café') ||
        query.contains('bar') || query.contains('coffee')) {
      return '56.30Z,56.10A,56.10C';
    }
    if (query.contains('hotel') || query.contains('hôtel')) return '55.10Z';
    if (query.contains('pharm')) return '47.73Z';
    if (query.contains('boulanger') || query.contains('bakery')) {
      return '10.71C';
    }
    if (query.contains('garage') || query.contains('car_repair')) {
      return '45.20A,45.20B';
    }
    return null;
  }

  static Uri buildUri({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String nafCodes,
    int page = 1,
    bool sortBySize = false,
  }) {
    return Uri.https(_url, '/near_point', {
      'lat': lat.toStringAsFixed(6),
      'long': lng.toStringAsFixed(6),
      'radius': (radiusMeters / 1000).toStringAsFixed(2),
      'page': '$page',
      'per_page': '25',
      if (sortBySize) 'sort_by_size': 'true',
      if (nafCodes.isNotEmpty) 'activite_principale': nafCodes,
    });
  }

  Future<List<OSMPlace>> searchNearby({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String query,
    String languageCode = 'fr',
  }) async {
    if (!supportsLocation(lat, lng)) return const [];
    final nafCodes = nafCodesFor(query);
    final normalized = query.toLowerCase();
    final sortBySize = normalized.contains('grand compte') ||
        normalized.contains('grands comptes') ||
        normalized.contains('large enterprise');
    if (nafCodes == null) return const [];

    final results = <OSMPlace>[];
    final seen = <String>{};
    // Limite adaptee a la prospection : maximum 100 unites legales par zone.
    // La recherche reste paginee pour respecter les quotas de l'API publique.
    for (var page = 1; page <= 4; page++) {
      final uri = buildUri(
        lat: lat, lng: lng, radiusMeters: radiusMeters,
        nafCodes: nafCodes, page: page, sortBySize: sortBySize,
      );
      final res = await _client.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'Prospecto/1.6 (contact: contact@digitalsolutionsai.com)',
      }).timeout(const Duration(seconds: 7));
      if (res.statusCode != 200) {
        throw StateError('Annuaire FR HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body);
      if (data is! Map) throw const FormatException('Reponse Annuaire FR invalide');
      final businesses = data['results'];
      if (businesses is! List || businesses.isEmpty) break;

      for (final raw in businesses) {
        if (raw is! Map) continue;
        final business = Map<String, dynamic>.from(raw);
        if (business['etat_administratif'] == 'C') continue;
        final establishments = business['matching_etablissements'] is List
            ? business['matching_etablissements'] as List
            : const [];
        final candidates = establishments.isNotEmpty
            ? establishments
            : [business['siege']];

        for (final candidate in candidates) {
          if (candidate is! Map) continue;
          final item = Map<String, dynamic>.from(candidate);
          if (item['est_ouvert'] == false ||
              item['date_fermeture'] != null) continue;

          final coords = (item['coordonnees'] ?? '').toString().split(',');
          if (coords.length != 2) continue;
          final elat = double.tryParse(coords[0].trim());
          final elng = double.tryParse(coords[1].trim());
          if (elat == null || elng == null) continue;
          if (_meters(lat, lng, elat, elng) > radiusMeters) continue;

          final siret = (item['siret'] ?? '').toString().trim();
          if (siret.isEmpty || !seen.add(siret)) continue;

          final name = [
            item['enseigne'],
            item['denomination_usuelle'],
            business['nom_complet'],
            business['nom_raison_sociale'],
          ].map((e) => (e ?? '').toString().trim())
              .firstWhere((s) => s.isNotEmpty, orElse: () => '');
          if (name.isEmpty) continue;

          final code = (item['activite_principale'] ??
              business['activite_principale'] ?? '').toString();
          final address = (item['adresse'] ?? '').toString();
          final food = code.startsWith('56.');
          final hair = code.startsWith('96.02');
          results.add(OSMPlace(
            id: 'siret_$siret',
            name: name,
            address: address,
            lat: elat,
            lng: elng,
            category: food ? 'Restauration'
                : hair ? 'Coiffure' : 'Entreprise',
            source: 'Annuaire des Entreprises',
            siret: siret,
            nafCode: code,
          ));
        }
      }

      final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      if (page >= totalPages || businesses.length < 25) break;
    }
    return results;
  }

  static double _meters(double lat1, double lng1, double lat2, double lng2) {
    const earth = 6371000.0;
    final p1 = lat1 * pi / 180;
    final p2 = lat2 * pi / 180;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(p1) * cos(p2) * sin(dLng / 2) * sin(dLng / 2);
    return earth * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
