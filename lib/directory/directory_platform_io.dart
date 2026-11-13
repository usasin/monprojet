import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/osm_search_service.dart';
import 'directory_geometry.dart';
import 'directory_models.dart';
import 'directory_platform_stub.dart' as stub;

DirectoryBackend createDirectoryBackend() => Platform.isAndroid
    ? NativeDirectoryBackend()
    : stub.createDirectoryBackend();

/// The private directory is independent of prospects, preferences and Firebase.
/// Immutable SQLite blobs and append-only commit markers keep the previous
/// version usable if the process stops during download, validation or activation.
class NativeDirectoryBackend implements DirectoryBackend {
  final Future<Directory> Function() supportDirectory;
  final DatabaseFactory factory;
  Future<void> _tail = Future.value();
  final Map<String, String> _verifiedFiles = {};
  final Set<String> _validatedFiles = {};
  bool _rtreeUnsupported = false;
  final HttpClient Function() _httpClient;
  NativeDirectoryBackend({
    Future<Directory> Function()? supportDirectory,
    DatabaseFactory? factory,
    HttpClient Function()? httpClient,
  })  : supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        factory = factory ?? databaseFactory,
        _httpClient = httpClient ?? HttpClient.new;
  @override
  bool get supported => true;

  Future<T> _locked<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<Directory> _root() async {
    final root = Directory(
      p.join(
        (await supportDirectory()).path,
        'prospecto_national_directory_v1',
      ),
    );
    await root.create(recursive: true);
    return root;
  }

  Future<List<Map<String, dynamic>>> _events(Directory root) async {
    final files = await root
        .list()
        .where(
          (f) =>
              f is File &&
              p.basename(f.path).startsWith('commit-') &&
              f.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final result = <Map<String, dynamic>>[];
    for (final file in files) {
      if (await file.length() > 1024 * 1024)
        throw const DirectoryException('Journal annuaire invalide.');
      final data = jsonDecode(await file.readAsString());
      if (data is! Map || data['pack_id'] is! String)
        throw const DirectoryException('Journal annuaire endommagé.');
      result.add(Map<String, dynamic>.from(data));
    }
    return result;
  }

  List<DirectoryPack> _active(List<Map<String, dynamic>> events) {
    final states = <String, Map<String, dynamic>>{};
    for (final event in events) {
      states[event['pack_id'] as String] = event;
    }
    return states.values
        .where((e) => e['removed'] != true)
        .map((e) => DirectoryPack(Map<String, dynamic>.from(e['pack'] as Map)))
        .toList();
  }

  Future<void> _commit(Directory root, Map<String, dynamic> event) async {
    // A fresh name avoids replace/rename differences between host platforms.
    // Rename of the flushed marker is the only activation operation.
    final existing = await root
        .list()
        .where(
          (f) =>
              p.basename(f.path).startsWith('commit-') &&
              f.path.endsWith('.json'),
        )
        .toList();
    existing.sort((a, b) => a.path.compareTo(b.path));
    var sequence = DateTime.now().microsecondsSinceEpoch;
    if (existing.isNotEmpty) {
      final last = int.tryParse(
            p.basename(existing.last.path).substring(7).split('.').first,
          ) ??
          0;
      if (sequence <= last) sequence = last + 1;
    }
    final file = File(
      p.join(
        root.path,
        'commit-${sequence.toString().padLeft(20, '0')}.json.tmp',
      ),
    );
    await file.writeAsString(jsonEncode(event), flush: true);
    await file.rename(file.path.substring(0, file.path.length - 4));
  }

  @override
  Future<List<DirectoryPack>> installed() =>
      _locked(() async => _active(await _events(await _root())));

  Future<void> _download(Uri uri, File target, int expected) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)
      throw const DirectoryException(
        'Une URL HTTPS sans identifiants est requise.',
      );
    final client = _httpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 20);
    IOSink? sink;
    try {
      // Release assets use short-lived HTTPS download URLs. Follow a bounded
      // chain, with no credentials, and verify the final bytes before install.
      var current = uri;
      final visited = <Uri>{};
      HttpClientResponse? response;
      for (var hop = 0; hop <= 5; hop++) {
        if (current.scheme != 'https' ||
            current.host.isEmpty ||
            current.userInfo.isNotEmpty ||
            current.hasFragment ||
            !visited.add(current)) {
          throw const DirectoryException(
              'Redirection de téléchargement non sûre.');
        }
        final request =
            await client.getUrl(current).timeout(const Duration(seconds: 30));
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 30));
        if (!const [301, 302, 303, 307, 308].contains(response.statusCode))
          break;
        final next = response.headers.value(HttpHeaders.locationHeader);
        await response.listen((_) {}).cancel();
        if (next == null || hop == 5) {
          throw const DirectoryException(
              'Lien de téléchargement invalide ou trop indirect.');
        }
        current = current.resolve(next);
        response = null;
      }
      if (response == null)
        throw const DirectoryException('Téléchargement indisponible.');
      if (response.statusCode != 200)
        throw DirectoryException(
          'Téléchargement HTTP ${response.statusCode}.',
        );
      if (response.contentLength > expected)
        throw const DirectoryException('Taille du téléchargement dépassée.');
      sink = target.openWrite();
      var bytes = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes += chunk.length;
        if (bytes > expected)
          throw const DirectoryException('Taille du téléchargement dépassée.');
        sink.add(chunk);
      }
      await sink.flush();
      if (bytes != expected)
        throw const DirectoryException(
          'Téléchargement tronqué ou taille incorrecte.',
        );
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  @override
  Future<String> fetchCatalog(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty)
      throw const DirectoryException('Lien catalogue HTTPS requis.');
    final client = _httpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      final response = await request.close().timeout(
            const Duration(seconds: 30),
          );
      if (response.statusCode != 200)
        throw DirectoryException('Catalogue HTTP ${response.statusCode}.');
      final data = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (data.length + chunk.length > 4 * 1024 * 1024)
          throw const DirectoryException(
            'Catalogue trop volumineux (4 Mo maximum).',
          );
        data.addAll(chunk);
      }
      return utf8.decode(data);
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  @override
  Future<void> install(
    DirectoryPack pack, {
    String? localFile,
    List<int>? bytes,
  }) =>
      _locked(() async {
        pack.ensureInstallable();
        final root = await _root();
        final stage = Directory(
          p.join(root.path, 'staging-${DateTime.now().microsecondsSinceEpoch}'),
        );
        await stage.create();
        final compressed = File(p.join(stage.path, 'pack.sqlite.gz'));
        final sqlite = File(p.join(stage.path, 'pack.sqlite'));
        try {
          if (bytes != null) {
            if (localFile != null || bytes.length != pack.gzipBytes) {
              throw const DirectoryException(
                  'Taille du pack inclus incorrecte.');
            }
            await compressed.writeAsBytes(bytes, flush: true);
          } else if (localFile != null) {
            final input = File(localFile);
            if (await input.length() != pack.gzipBytes)
              throw const DirectoryException(
                  'Taille du fichier local incorrecte.');
            await input.copy(compressed.path);
          } else {
            final url = pack.url;
            if (url == null || url.scheme != 'https')
              throw const DirectoryException(
                'Ce pack requiert un fichier local ou une URL HTTPS.',
              );
            await _download(url, compressed, pack.gzipBytes);
          }
          if (await compressed.length() != pack.gzipBytes ||
              await _hash(compressed) != pack.gzipHash)
            throw const DirectoryException(
                'Intégrité gzip incorrecte (SHA-256).');
          final sink = sqlite.openWrite();
          var expanded = 0;
          try {
            await for (final chunk
                in gzip.decoder.bind(compressed.openRead())) {
              expanded += chunk.length;
              if (expanded > pack.sqliteBytes)
                throw const DirectoryException(
                    'Décompression trop volumineuse.');
              sink.add(chunk);
            }
            await sink.flush();
          } finally {
            await sink.close();
          }
          if (expanded != pack.sqliteBytes ||
              await _hash(sqlite) != pack.sqliteHash)
            throw const DirectoryException(
              'Intégrité SQLite incorrecte (SHA-256).',
            );
          final database = await factory.openDatabase(
            sqlite.path,
            options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
          );
          try {
            await _validate(database, pack);
          } finally {
            await database.close();
          }
          final destination =
              File(p.join(root.path, '${pack.sqliteHash}.sqlite'));
          if (await destination.exists()) {
            if (await _hash(destination) != pack.sqliteHash) {
              throw const DirectoryException(
                'Version stockée endommagée : retirez le pack avant de le réinstaller.',
              );
            }
          } else {
            await sqlite.rename(destination.path);
          }
          await _commit(root, {'pack_id': pack.id, 'pack': pack.json});
        } finally {
          // Only generated immediate children of our private directory are removed.
          if (p.dirname(stage.path) == root.path &&
              p.basename(stage.path).startsWith('staging-') &&
              await stage.exists()) await stage.delete(recursive: true);
        }
      });

  Future<void> _validate(Database db, DirectoryPack pack) async {
    final check = await db.rawQuery('PRAGMA quick_check');
    if (check.length != 1 || check.first.values.first != 'ok')
      throw const DirectoryException('Le pack SQLite est endommagé.');
    final required = <String, List<String>>{
      'pack_metadata': ['key', 'value'],
      'establishments': [
        'id',
        'siret',
        'siren',
        'name',
        'address',
        'postal_code',
        'commune_code',
        'department',
        'region',
        'lat',
        'lon',
        'naf_code',
        'naf_version',
        'employee_band',
        'enterprise_size',
        'active',
        'source',
        'source_date',
        'geo_quality',
      ],
      'establishment_categories': ['establishment_id', 'category_id'],
      'categories': ['id', 'label'],
      'energy_observations': [
        'id',
        'scope',
        'scope_id',
        'year',
        'consumption_kwh',
        'power_kw',
        'power_kva',
        'segment',
        'naf_code',
        'source',
        'source_url',
        'source_date',
        'status',
        'quality_note',
      ],
    };
    for (final entry in required.entries) {
      final columns = (await db.rawQuery(
        'PRAGMA table_info(${entry.key})',
      ))
          .map((r) => r['name'])
          .toSet();
      if (!columns.containsAll(entry.value))
        throw DirectoryException('Schéma incompatible : ${entry.key}.');
    }
    final metadata = {
      for (final row in await db.query('pack_metadata'))
        row['key']: row['value'],
    };
    if (metadata['schema_version'] != '1')
      throw const DirectoryException('Version de schéma incompatible.');
    for (final key in [
      'pack_id',
      'version',
      'department',
      'data_date',
      'coverage_complete',
      'is_demo',
    ]) {
      if ('${metadata[key]}' != '${pack.json[key]}')
        throw DirectoryException('Métadonnées incohérentes : $key.');
    }
    if (jsonEncode(_canonical(jsonDecode('${metadata['coverage_geojson']}'))) !=
        jsonEncode(_canonical(pack.geometry)))
      throw const DirectoryException(
        'Couverture SQLite différente du catalogue.',
      );
  }

  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  @override
  Future<void> remove(String packId) => _locked(() async {
        final root = await _root();
        final events = await _events(root);
        await _commit(root, {'pack_id': packId, 'removed': true});
        final otherHashes = _active(
          events,
        ).where((p) => p.id != packId).map((p) => p.sqliteHash).toSet();
        for (final event in events.where(
          (e) => e['pack_id'] == packId && e['pack'] != null,
        )) {
          final pack = DirectoryPack(
            Map<String, dynamic>.from(event['pack'] as Map),
          );
          if (!otherHashes.contains(pack.sqliteHash)) {
            final file = File(p.join(root.path, '${pack.sqliteHash}.sqlite'));
            if (await file.exists()) await file.delete();
            _verifiedFiles.remove(file.path);
            _validatedFiles.remove(file.path);
          }
        }
      });
  @override
  Future<bool> rollback(String packId) => _locked(() async {
        final root = await _root();
        final events = await _events(root);
        final active = _active(events).where((p) => p.id == packId).firstOrNull;
        if (active == null) return false;
        for (final event
            in events.reversed.where((e) => e['pack_id'] == packId)) {
          if (event['removed'] == true) break;
          final candidate = DirectoryPack(
            Map<String, dynamic>.from(event['pack'] as Map),
          );
          if (candidate.sqliteHash == active.sqliteHash) continue;
          final file =
              File(p.join(root.path, '${candidate.sqliteHash}.sqlite'));
          if (!await file.exists() || await _hash(file) != candidate.sqliteHash)
            continue;
          await _commit(root, {'pack_id': packId, 'pack': candidate.json});
          return true;
        }
        return false;
      });

  @override
  Future<List<DirectoryRecord>> query(
    DirectoryPack pack,
    double lat,
    double lon,
    int radius,
    List<String>? categories,
  ) =>
      _locked(() async {
        final root = await _root();
        final file = File(p.join(root.path, '${pack.sqliteHash}.sqlite'));
        final stat = await file.stat();
        final fingerprint =
            '${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stat.changed.microsecondsSinceEpoch}';
        if (_verifiedFiles[file.path] != fingerprint) {
          if (stat.size != pack.sqliteBytes ||
              await _hash(file) != pack.sqliteHash)
            throw const DirectoryException('Pack local endommagé (SHA-256).');
          _verifiedFiles[file.path] = fingerprint;
          _validatedFiles.remove(file.path);
        }
        final db = await factory.openDatabase(
          file.path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        try {
          if (!_validatedFiles.contains(file.path)) {
            await _validate(db, pack);
            _validatedFiles.add(file.path);
          }
          final dy = radius / 111000.0;
          final dx = dy / math.cos(lat * math.pi / 180).abs().clamp(0.01, 1);
          final args = <Object?>[lat - dy, lat + dy, lon - dx, lon + dx];
          final categorySql = categories == null
              ? ''
              : ' AND EXISTS (SELECT 1 FROM establishment_categories ec WHERE ec.establishment_id=e.id AND ec.category_id IN (${List.filled(categories.length, '?').join(',')}))';
          if (categories != null) args.addAll(categories);
          final hasRtree = !_rtreeUnsupported &&
              (await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='establishment_rtree'",
              ))
                  .isNotEmpty;
          const select =
              "SELECT e.*, (SELECT GROUP_CONCAT(c.label, ', ') FROM categories c JOIN establishment_categories ec ON ec.category_id=c.id WHERE ec.establishment_id=e.id) AS directory_category FROM establishments e";
          final plainSql =
              '$select WHERE e.active=1 AND e.lat BETWEEN ? AND ? AND e.lon BETWEEN ? AND ?$categorySql';
          List<Map<String, Object?>> rows;
          if (hasRtree) {
            try {
              rows = await db.rawQuery(
                  '$select JOIN establishment_rtree r ON r.id=e.rowid WHERE e.active=1 AND r.max_lat>=? AND r.min_lat<=? AND r.max_lon>=? AND r.min_lon<=?$categorySql',
                  args);
            } catch (error) {
              // Android vendors may omit the RTree module even when a pack
              // created elsewhere contains its virtual table. The ordinary
              // indexed columns remain usable without changing the pack.
              if (!error
                  .toString()
                  .toLowerCase()
                  .contains('no such module: rtree')) rethrow;
              _rtreeUnsupported = true;
              rows = await db.rawQuery(plainSql, args);
            }
          } else {
            rows = await db.rawQuery(plainSql, args);
          }
          final nearby = rows
              .where((row) =>
                  directoryDistance(lat, lon, (row['lat'] as num).toDouble(),
                      (row['lon'] as num).toDouble()) <=
                  radius)
              .toList();
          final sirets = nearby
              .map((row) => '${row['siret'] ?? ''}')
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
          final bySiret = <String, List<Map<String, Object?>>>{};
          for (var offset = 0; offset < sirets.length; offset += 400) {
            final batch =
                sirets.sublist(offset, math.min(offset + 400, sirets.length));
            final observations = await db.rawQuery(
                "SELECT * FROM energy_observations WHERE scope='siret' AND scope_id IN (${List.filled(batch.length, '?').join(',')}) ORDER BY year DESC",
                batch);
            for (final observation in observations) {
              bySiret
                  .putIfAbsent('${observation['scope_id']}', () => [])
                  .add(observation);
            }
          }
          final byEstablishment = <String, List<Map<String, Object?>>>{};
          final hasGeographies = (await db.rawQuery(
                  "SELECT name FROM sqlite_master WHERE type='table' AND name='establishment_geographies'"))
              .isNotEmpty;
          if (hasGeographies) {
            final ids = nearby.map((row) => row['id']).toList();
            for (var offset = 0; offset < ids.length; offset += 400) {
              final batch =
                  ids.sublist(offset, math.min(offset + 400, ids.length));
              final observations = await db.rawQuery(
                  "SELECT eo.*, g.establishment_id AS directory_establishment_id, g.match_quality AS context_match_quality FROM energy_observations eo JOIN establishment_geographies g ON g.scope=eo.scope AND g.scope_id=eo.scope_id WHERE g.establishment_id IN (${List.filled(batch.length, '?').join(',')}) AND g.scope IN ('address','iris') ORDER BY eo.year DESC",
                  batch);
              for (final observation in observations) {
                byEstablishment
                    .putIfAbsent('${observation['directory_establishment_id']}',
                        () => [])
                    .add(observation);
              }
            }
          }
          final contextEnergy = await db.rawQuery(
              "SELECT * FROM energy_observations WHERE scope='department' AND scope_id=? ORDER BY year DESC",
              [pack.department]);
          final output = <DirectoryRecord>[];
          for (final row in nearby) {
            final rowLat = (row['lat'] as num).toDouble(),
                rowLon = (row['lon'] as num).toDouble();
            final siret = '${row['siret'] ?? ''}';
            final id =
                siret.isNotEmpty ? 'siret_$siret' : 'annuaire:${row['id']}';
            final energy = <Map<String, Object?>>[
              ...?bySiret[siret],
              ...?byEstablishment['${row['id']}'],
              ...contextEnergy
            ];
            output.add(
              DirectoryRecord(
                OSMPlace(
                  id: id,
                  name: '${row['name']}',
                  address: '${row['address']}',
                  lat: rowLat,
                  lng: rowLon,
                  category: '${row['directory_category'] ?? ''}',
                  source:
                      '${pack.demo ? 'DÉMONSTRATION · ' : ''}${row['source'] ?? 'Annuaire public local'}',
                  siret: siret.isEmpty ? null : siret,
                  nafCode: row['naf_code'] as String?,
                ),
                row,
                energy,
                pack,
              ),
            );
          }
          output.sort(
            (a, b) => directoryDistance(
              lat,
              lon,
              a.place.lat,
              a.place.lng,
            ).compareTo(directoryDistance(lat, lon, b.place.lat, b.place.lng)),
          );
          return output;
        } finally {
          await db.close();
        }
      });
}
