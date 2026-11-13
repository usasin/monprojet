import '../services/osm_search_service.dart';

class DirectoryException implements Exception {
  final String message;
  const DirectoryException(this.message);
  @override
  String toString() => message;
}

class DirectoryPack {
  final Map<String, dynamic> json;
  DirectoryPack(Map<String, dynamic> value) : json = Map.unmodifiable(value) {
    for (final key in ['pack_id', 'version', 'data_date']) {
      if (json[key] is! String || (json[key] as String).isEmpty) {
        throw DirectoryException('Catalogue : $key manquant.');
      }
    }
    if (json['department'] is! String ||
        ((json['department'] as String).isEmpty &&
            !(json['partition'] == 'region' &&
                json['region'] is String &&
                (json['region'] as String).isNotEmpty))) {
      throw const DirectoryException('Catalogue : territoire manquant.');
    }
    for (final key in ['gzip_sha256', 'sqlite_sha256']) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch('${json[key]}')) {
        throw DirectoryException('Catalogue : $key invalide.');
      }
    }
    for (final key in ['gzip_size_bytes', 'sqlite_size_bytes']) {
      if (json[key] is! int || (json[key] as int) <= 0) {
        throw DirectoryException('Catalogue : taille $key invalide.');
      }
    }
    if (json['coverage_complete'] is! bool ||
        json['is_demo'] is! bool ||
        json['coverage_geojson'] is! Map) {
      throw const DirectoryException('Catalogue : couverture invalide.');
    }
  }
  String get id => json['pack_id'] as String;
  String get version => json['version'] as String;
  String get department => json['department'] as String;
  String get territory => department.isNotEmpty
      ? 'département $department'
      : 'région ${json['region']}';
  bool get complete => json['coverage_complete'] == true;
  bool get demo => json['is_demo'] == true;
  int get gzipBytes => json['gzip_size_bytes'] as int;
  int get sqliteBytes => json['sqlite_size_bytes'] as int;
  static const maxGzipBytes = 512 * 1024 * 1024;
  static const maxSqliteBytes = 2 * 1024 * 1024 * 1024;
  bool get mobileCompatible =>
      gzipBytes <= maxGzipBytes && sqliteBytes <= maxSqliteBytes;
  void ensureInstallable() {
    if (!mobileCompatible)
      throw const DirectoryException(
          'Ce pack dépasse les limites du mobile. Choisissez un département plus petit.');
  }

  String get sqliteHash => json['sqlite_sha256'] as String;
  String get gzipHash => json['gzip_sha256'] as String;
  Map<String, dynamic> get geometry =>
      Map<String, dynamic>.from(json['coverage_geojson'] as Map);
  Uri? get url {
    final value = json['url'];
    return value is String && value.isNotEmpty ? Uri.parse(value) : null;
  }
}

List<DirectoryPack> parseDirectoryCatalog(
  Map<String, dynamic> json, {
  Uri? base,
}) {
  if (json['schema_version'] != 1 || json['packs'] is! List) {
    throw const DirectoryException(
      'Catalogue non pris en charge (schema_version 1 requis).',
    );
  }
  final seen = <String>{};
  return (json['packs'] as List).map((entry) {
    final data = Map<String, dynamic>.from(entry as Map);
    if (base != null && data['url'] is String) {
      data['url'] = base.resolve(data['url'] as String).toString();
    }
    final pack = DirectoryPack(data);
    if (!seen.add(pack.id))
      throw const DirectoryException('Identifiant pack en double.');
    return pack;
  }).toList();
}

class DirectoryRecord {
  final OSMPlace place;
  final Map<String, Object?> establishment;
  final List<Map<String, Object?>> energy;
  final DirectoryPack pack;
  const DirectoryRecord(this.place, this.establishment, this.energy, this.pack);
}

class DirectorySearchResult {
  final List<OSMPlace> places;
  final Map<String, DirectoryRecord> details;
  final String notice;
  final bool local;

  /// An extract, a crossing circle or an unavailable local pack cannot prove
  /// that all establishments in this radius have been searched.
  final bool partial;
  final bool networkUnavailable;
  const DirectorySearchResult(
    this.places, {
    this.details = const {},
    this.notice = '',
    this.local = false,
    this.partial = false,
    this.networkUnavailable = false,
  });
}

abstract class DirectoryBackend {
  bool get supported;
  Future<List<DirectoryPack>> installed();
  Future<void> install(DirectoryPack pack,
      {String? localFile, List<int>? bytes});
  Future<void> remove(String packId);
  Future<bool> rollback(String packId);
  Future<String> fetchCatalog(Uri uri);
  Future<List<DirectoryRecord>> query(
    DirectoryPack pack,
    double lat,
    double lon,
    int radius,
    List<String>? categories,
  );
}
