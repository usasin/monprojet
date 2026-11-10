import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_prospect_gps/directory/directory_catalog_service.dart';
import 'package:ai_prospect_gps/directory/directory_platform_io.dart';
import 'package:ai_prospect_gps/directory/directory_service.dart';

// This opt-in test performs genuine anonymous HTTPS downloads. Default unit
// tests remain independent of the availability of GitHub and the network.
class PublicNetwork extends HttpOverrides {}

void main() {
  test(
      'public catalog -> release redirect -> verified SQLite -> offline search',
      () async {
    sqfliteFfiInit();
    final root =
        await Directory.systemTemp.createTemp('prospecto-public-pack-');
    try {
      final backend = NativeDirectoryBackend(
          supportDirectory: () async => root,
          factory: databaseFactoryFfi,
          httpClient: () => PublicNetwork().createHttpClient(null));
      final catalog = DirectoryCatalogService.configured(backend.fetchCatalog)!;
      final packs = await catalog.load();
      expect(packs, hasLength(1));
      final pack = packs.single;
      expect(pack.id, 'fr-75');
      expect(pack.demo, isFalse);
      expect(pack.complete, isFalse);
      expect(pack.json['rows'], 50);
      expect(pack.gzipHash,
          '0d78ae04642cc8ecdc2d246ff27d8c9424a411fb50faa0175dc59513c4a6a95e');
      await backend.install(pack);
      expect((await backend.installed()).single.sqliteHash, pack.sqliteHash);
      expect(
          await backend.query(pack, 48.86, 2.33, 50000, null), hasLength(50));
      final categories = DirectoryCategories(jsonDecode(
          await File('tools/national_directory/categories.json')
              .readAsString()) as Map<String, dynamic>);
      final service = DirectoryService(
          backend: backend, categories: () async => categories);
      final local = await service.search(
          lat: 48.86,
          lon: 2.33,
          radius: 2000,
          query: 'restaurant',
          fallback: () async => throw const SocketException('Offline test'));
      expect(local.places, hasLength(19));
      expect(local.networkUnavailable, isTrue);
      expect(local.partial, isTrue);
      expect(local.local, isTrue);
    } finally {
      expect(p.isWithin(Directory.systemTemp.path, root.path), isTrue);
      await root.delete(recursive: true);
    }
  },
      skip: !const bool.fromEnvironment('PROSPECTO_VERIFY_PUBLIC_PACK'),
      timeout: const Timeout(Duration(seconds: 90)));
}
