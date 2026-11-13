import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_platform_io.dart';

class UnusedFactory extends Fake implements DatabaseFactory {}

Map<String, dynamic> metadata(String id,
        {int gzip = 100, int sqlite = 100, bool region = false}) =>
    {
      'pack_id': id,
      'version': 'test',
      'department': region ? '' : '75',
      'region': '11',
      'partition': region ? 'region' : 'department',
      'data_date': '2026-10-01',
      'coverage_complete': false,
      'is_demo': true,
      'coverage_geojson': <String, dynamic>{},
      'gzip_sha256': List.filled(64, 'a').join(),
      'sqlite_sha256': List.filled(64, 'b').join(),
      'gzip_size_bytes': gzip,
      'sqlite_size_bytes': sqlite,
      'url': 'https://example.test/pack.sqlite.gz',
    };
void main() {
  test(
      'oversized region does not hide compatible departments in the same catalogue',
      () {
    final packs = parseDirectoryCatalog({
      'schema_version': 1,
      'packs': [
        metadata('fr-region-11',
            region: true, sqlite: DirectoryPack.maxSqliteBytes + 1),
        metadata('fr-75')
      ]
    });
    expect(packs.length, 2);
    expect(packs.first.mobileCompatible, isFalse);
    expect(packs.last.mobileCompatible, isTrue);
  });
  test(
      'exact storage limits remain supported and limit plus one is unsupported',
      () {
    expect(
        DirectoryPack(metadata('fr-75',
                gzip: DirectoryPack.maxGzipBytes,
                sqlite: DirectoryPack.maxSqliteBytes))
            .mobileCompatible,
        isTrue);
    expect(
        DirectoryPack(metadata('fr-75', gzip: DirectoryPack.maxGzipBytes + 1))
            .mobileCompatible,
        isFalse);
    expect(
        DirectoryPack(
                metadata('fr-75', sqlite: DirectoryPack.maxSqliteBytes + 1))
            .mobileCompatible,
        isFalse);
    expect(() => DirectoryPack(metadata('fr-75', gzip: 0)),
        throwsA(isA<DirectoryException>()));
    expect(
        () => parseDirectoryCatalog({
              'schema_version': 1,
              'packs': [metadata('fr-75'), metadata('fr-75')]
            }),
        throwsA(isA<DirectoryException>()));
  });
  test('every oversized install path fails before filesystem or network access',
      () async {
    var rootCalls = 0;
    final backend = NativeDirectoryBackend(
        factory: UnusedFactory(),
        supportDirectory: () async {
          rootCalls++;
          throw StateError('must not open filesystem');
        });
    final pack =
        DirectoryPack(metadata('fr-75', gzip: DirectoryPack.maxGzipBytes + 1));
    await expectLater(
        backend.install(pack), throwsA(isA<DirectoryException>()));
    await expectLater(backend.install(pack, localFile: 'missing.sqlite.gz'),
        throwsA(isA<DirectoryException>()));
    await expectLater(backend.install(pack, bytes: const [1, 2, 3]),
        throwsA(isA<DirectoryException>()));
    expect(rootCalls, 0);
  });
}
