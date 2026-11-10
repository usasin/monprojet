import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_catalog_service.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_page.dart';
import 'package:ai_prospect_gps/directory/directory_service.dart';

Map<String, dynamic> fixture() => jsonDecode(
        File('test/fixtures/prospecto_api_catalog.json').readAsStringSync())
    as Map<String, dynamic>;

class StaticBackend extends Fake implements DirectoryBackend {
  final installedPacks = <DirectoryPack>[];
  @override
  bool get supported => true;
  @override
  Future<List<DirectoryPack>> installed() async => installedPacks.toList();
  @override
  Future<void> install(DirectoryPack pack,
      {String? localFile, List<int>? bytes}) async {
    expect(localFile, isNull);
    expect(bytes, isNull);
    installedPacks.add(pack);
  }
}

void main() {
  test('versioned static catalog resolves pack paths and verifies pointer hash',
      () async {
    final data = fixture();
    data['packs'][0]['url'] = 'paris.sqlite.gz';
    final body = jsonEncode(data);
    final requests = <Uri>[];
    final catalog = DirectoryCatalogService(
        'https://files.example/current.json', fetch: (uri) async {
      requests.add(uri);
      return uri.path == '/current.json'
          ? jsonEncode({
              'schema_version': 1,
              'catalog': 'versions/v1/catalog.json',
              'catalog_sha256': sha256.convert(utf8.encode(body)).toString()
            })
          : body;
    });
    final packs = await catalog.load();
    expect(packs.single.url.toString(),
        'https://files.example/versions/v1/paris.sqlite.gz');
    expect(packs.single.json['rows'], 50);
    expect(packs.single.complete, isFalse);
    expect(requests.map((u) => u.path),
        ['/current.json', '/versions/v1/catalog.json']);
  });

  test('wrong catalog hash cannot activate a new list', () async {
    final catalog = DirectoryCatalogService(
        'https://files.example/current.json',
        fetch: (uri) async => uri.path == '/current.json'
            ? jsonEncode({
                'schema_version': 1,
                'catalog': 'catalog.json',
                'catalog_sha256': '0' * 64
              })
            : jsonEncode(fixture()));
    await expectLater(catalog.load(), throwsA(isA<DirectoryException>()));
  });

  test('loops and excessive indirection stop after bounded requests', () async {
    var calls = 0;
    final cycle = DirectoryCatalogService('https://files.example/current.json',
        fetch: (_) async {
      calls++;
      return jsonEncode({'schema_version': 1, 'catalog': 'current.json'});
    });
    await expectLater(cycle.load(), throwsException);
    expect(calls, 1);
    calls = 0;
    final deep = DirectoryCatalogService('https://files.example/current.json',
        fetch: (_) async {
      calls++;
      return jsonEncode({'schema_version': 1, 'catalog': 'next$calls.json'});
    });
    await expectLater(deep.load(), throwsException);
    expect(calls, 3);
  });

  test('untrusted transport, demo data and mismatched versions are rejected',
      () async {
    for (final address in [
      'http://files.example/current.json',
      'https://a:b@files.example/x',
      'file:///x'
    ]) {
      expect(() => DirectoryCatalogService(address, fetch: (_) async => ''),
          throwsException);
    }
    for (final change in [
      (Map<String, dynamic> p) => p['url'] = 'http://files.example/pack.gz',
      (Map<String, dynamic> p) => p['is_demo'] = true,
      (Map<String, dynamic> p) => p['version'] = 'different',
    ]) {
      final data = fixture();
      change(data['packs'][0] as Map<String, dynamic>);
      final service = DirectoryCatalogService(
          'https://files.example/catalog.json',
          fetch: (_) async => jsonEncode(data));
      await expectLater(service.load(), throwsException);
    }
  });

  test('oversized and duplicate catalogs are rejected', () async {
    final huge = DirectoryCatalogService('https://files.example/catalog.json',
        fetch: (_) async => 'x' * (4 * 1024 * 1024 + 1));
    await expectLater(huge.load(), throwsException);
    final data = fixture();
    (data['packs'] as List).add((data['packs'] as List).first);
    final repeated = DirectoryCatalogService(
        'https://files.example/catalog.json',
        fetch: (_) async => jsonEncode(data));
    await expectLater(repeated.load(), throwsException);
  });

  testWidgets(
      'static catalog downloads directly without API, Drive or file picker',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var fileRequests = 0;
    final backend = StaticBackend();
    final catalog = DirectoryCatalogService(
        'https://files.example/catalog.json', fetch: (_) async {
      fileRequests++;
      return jsonEncode(fixture());
    });
    await tester.pumpWidget(MaterialApp(
        home: DirectoryPage(
            directory: DirectoryService(backend: backend), catalog: catalog)));
    await tester.pumpAndSettle();
    final download = find.byKey(const ValueKey('download-territory-fr-75'));
    await tester.scrollUntilVisible(download, 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(download);
    await tester.pumpAndSettle();
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(fileRequests, 1);
    expect(backend.installedPacks.single.id, 'fr-75');
    expect(find.text('Choisir la liste des départements'), findsNothing);
    expect(find.byKey(const ValueKey('use-territory-fr-75')), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
