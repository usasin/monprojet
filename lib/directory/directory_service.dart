import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/osm_search_service.dart';
import 'directory_geometry.dart';
import 'directory_models.dart';
import 'directory_platform_stub.dart'
    if (dart.library.io) 'directory_platform_io.dart' as platform;

typedef DirectoryFallback = Future<List<OSMPlace>> Function();

class DirectoryCategories {
  final List<Map<String, dynamic>> categories;
  DirectoryCategories(Map<String, dynamic> data)
      : categories = (data['categories'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList() {
    if (data['schema_version'] != 1)
      throw const DirectoryException(
        'Référentiel de catégories non pris en charge.',
      );
  }
  static String normalize(String value) {
    var result = value.toLowerCase().trim();
    const accents = 'àâäéèêëîïôöùûüç';
    const ascii = 'aaaeeeeiioouuuc';
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], ascii[i]);
    }
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Null = all establishments, empty = unsupported (must use fallback).
  List<String>? resolve(String query) {
    if (query.trim().isEmpty) return null;
    final output = <String>{};
    for (final part in query.split(RegExp(r'[,;]'))) {
      final normalized = normalize(part);
      final matches = categories.where(
        (c) => [
          c['id'],
          c['label'],
          ...?c['synonyms'] as List?,
        ].any((v) => normalize('$v') == normalized),
      );
      if (matches.isEmpty) return [];
      output.addAll(matches.map((c) => c['id'] as String));
    }
    return output.toList();
  }
}

class DirectoryService {
  static final instance = DirectoryService();
  final DirectoryBackend backend;
  final Future<DirectoryCategories> Function() _loadCategories;
  bool allowDemo = false;
  DirectoryService({
    DirectoryBackend? backend,
    Future<DirectoryCategories> Function()? categories,
  })  : backend = backend ?? platform.createDirectoryBackend(),
        _loadCategories = categories ??
            (() async => DirectoryCategories(
                  jsonDecode(
                    await rootBundle.loadString(
                      'tools/national_directory/categories.json',
                    ),
                  ) as Map<String, dynamic>,
                ));
  bool get supported => backend.supported;

  Future<DirectorySearchResult> search({
    required double lat,
    required double lon,
    required int radius,
    required String query,
    required DirectoryFallback fallback,
  }) async {
    if (!supported) return DirectorySearchResult(await fallback());
    var fallbackNotice = 'Zone sans pack complet : complément en ligne.';
    final localRows = <String, DirectoryRecord>{};
    final localErrors = <Object>[];
    var completeCoverage = false;
    var demoSearched = false;
    try {
      final categories = (await _loadCategories()).resolve(query);
      if (categories != null && categories.isEmpty) {
        fallbackNotice = 'Catégorie non couverte : recherche en ligne.';
      } else {
        final packs = await backend.installed();
        for (final pack in packs) {
          if (pack.demo && !allowDemo) continue;
          if (!directoryMayIntersectCircle(pack.geometry, lat, lon, radius)) continue;
          try {
            // Even an extract is useful. Geometry only decides whether a
            // successful pack may replace the network for the entire circle.
            final rows =
                await backend.query(pack, lat, lon, radius, categories);
            demoSearched = demoSearched || pack.demo;
            for (final row in rows) {
              localRows.putIfAbsent(row.place.id, () => row);
            }
            if (pack.complete &&
                directoryCoversCircle(pack.geometry, lat, lon, radius)) {
              completeCoverage = true;
            }
          } catch (error) {
            localErrors.add(error);
          }
        }
      }
    } catch (error) {
      localErrors.add(error);
    }
    final details = Map<String, DirectoryRecord>.from(localRows);
    final local = localRows.values.map((r) => r.place).toList();
    final demo = demoSearched ? 'DÉMONSTRATION · ' : '';
    if (completeCoverage) {
      return DirectorySearchResult(
        _sorted(local, lat, lon),
        local: true,
        details: details,
        notice:
            '${demo}Annuaire local · zone entièrement couverte par un pack déclaré complet.',
      );
    }
    if (localErrors.isNotEmpty) {
      fallbackNotice =
          'Un pack local est indisponible ou endommagé : secours en ligne.';
    } else if (local.isNotEmpty) {
      fallbackNotice =
          '${demo}Extrait local partiel · ${local.length} établissement(s) · complément en ligne. La France entière n’est pas chargée.';
    }
    // Keep network fallback outside local error handling: exactly one request.
    try {
      final online = await fallback();
      final merged = <OSMPlace>[...online];
      for (final place in local) {
        final duplicate = merged.indexWhere((other) => _same(other, place));
        if (duplicate < 0) {
          merged.add(place);
        } else {
          // Keep the online identifier used by existing selections; attach the
          // local record under that same identifier for the details sheet.
          final other = merged[duplicate];
          details[other.id] = localRows[place.id]!;
          merged[duplicate] = OSMPlace(
            id: other.id,
            name: other.name,
            address: other.address,
            lat: other.lat,
            lng: other.lng,
            category: other.category,
            phone: other.phone,
            email: other.email,
            website: other.website,
            openingHours: other.openingHours,
            instagram: other.instagram,
            facebook: other.facebook,
            linkedin: other.linkedin,
            source: other.source == null
                ? place.source
                : '${other.source} + annuaire local',
            siret: other.siret ?? place.siret,
            nafCode: other.nafCode ?? place.nafCode,
          );
        }
      }
      return DirectorySearchResult(
        _sorted(merged, lat, lon),
        details: details,
        partial: true,
        notice: fallbackNotice,
      );
    } catch (error) {
      if (local.isNotEmpty) {
        return DirectorySearchResult(
          _sorted(local, lat, lon),
          details: details,
          local: true,
          partial: true,
          networkUnavailable: true,
          notice:
              '${demo}Recherche en ligne indisponible. ${local.length} établissement(s) de l’extrait local seulement : résultats incomplets, aucune absence ne peut être conclue.',
        );
      }
      throw DirectoryException(
        '${localErrors.isEmpty ? '' : 'Annuaire local indisponible ou endommagé. '}'
        'Recherche en ligne indisponible. Aucun résultat local disponible ; cela ne signifie pas qu’il n’y a aucun établissement dans cette zone. Réessayez avec une connexion. ($error)',
      );
    }
  }

  static List<OSMPlace> _sorted(List<OSMPlace> places, double lat, double lon) {
    places.sort((a, b) => directoryDistance(lat, lon, a.lat, a.lng)
        .compareTo(directoryDistance(lat, lon, b.lat, b.lng)));
    return places;
  }

  static bool _same(OSMPlace a, OSMPlace b) {
    if (a.id == b.id) return true;
    if (a.siret?.isNotEmpty == true && b.siret?.isNotEmpty == true) {
      return a.siret == b.siret;
    }
    final name = DirectoryCategories.normalize(a.name);
    return name.isNotEmpty && name == DirectoryCategories.normalize(b.name) &&
        directoryDistance(a.lat, a.lng, b.lat, b.lng) <= 35;
  }
}
