import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_catalog_service.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_service.dart';
import 'package:ai_prospect_gps/directory/directory_page.dart';
import 'package:ai_prospect_gps/directory/directory_territories.dart';

DirectoryPack territory(String id, String department, String region) =>
    DirectoryPack({
      'schema_version': 1,
      'pack_id': id,
      'version': 'test',
      'department': department,
      'region': region,
      'partition': department.isEmpty ? 'region' : 'department',
      'data_date': '2026-10-01',
      'coverage_complete': false,
      'is_demo': true,
      'coverage_geojson': <String, dynamic>{},
      'gzip_sha256': List.filled(64, 'a').join(),
      'sqlite_sha256': List.filled(64, 'b').join(),
      'gzip_size_bytes': 100,
      'sqlite_size_bytes': 100,
    });

class ReadyBackend extends Fake implements DirectoryBackend {
  int queries = 0;
  @override
  bool get supported => true;
  @override
  Future<List<DirectoryPack>> installed() async =>
      [territory('fr-75', '75', '11')];
  @override
  Future<List<DirectoryRecord>> query(DirectoryPack pack, double lat,
      double lon, int radius, List<String>? categories) async {
    queries++;
    return [];
  }
}

void main() {
  test('department search uses department number, not a matching region number',
      () {
    final packs = [
      territory('fr-75', '75', '11'),
      territory('fr-33', '33', '75'),
      territory('region-75', '', '75')
    ];
    expect(
        filterDirectoryTerritories(packs, regions: false, query: '75')
            .map((p) => p.id),
        ['fr-75']);
    expect(
        filterDirectoryTerritories(packs,
                regions: true, query: 'nouvelle aquitaine')
            .map((p) => p.id),
        ['region-75']);
    expect(
        filterDirectoryTerritories([territory('fr-31', '31', '76')],
                regions: false, query: 'haute garonne')
            .single
            .id,
        'fr-31');
  });
  test('accented department names remain readable and searchable', () {
    final ardeche = territory('fr-07', '07', '84');
    expect(directoryTerritoryTitle(ardeche), '07 · Ardèche');
    expect(
        filterDirectoryTerritories([ardeche], regions: false, query: 'ardeche'),
        [ardeche]);
  });
  testWidgets('the screen counts only published downloadable departments',
      (tester) async {
    final pack = Map<String, dynamic>.from(
        territory('fr-75', '75', '11').json);
    pack['is_demo'] = false;
    pack['rows'] = 50;
    pack['url'] = 'https://example.test/75.sqlite.gz';
    final catalog = DirectoryCatalogService(
      'https://example.test/catalog.json',
      fetch: (_) async => jsonEncode({
        'schema_version': 1,
        'version': 'test',
        'packs': [pack],
      }),
    );
    final service = DirectoryService(backend: ReadyBackend());
    await tester.pumpWidget(MaterialApp(
      home: DirectoryPage(directory: service, catalog: catalog),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 département'), findsOneWidget);
    expect(find.text('0 régions'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('available-departments-chip')));
    await tester.tap(find.byKey(const Key('available-departments-chip')));
    await tester.pumpAndSettle();
    expect(find.textContaining('autres restent accessibles'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Régions (0)'));
    await tester.tap(find.text('Régions (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune zone dans cette liste'), findsOneWidget);
    await tester.tap(find.text('Aucune zone dans cette liste'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune région entière'), findsOneWidget);
  });

  testWidgets(
      'using an installed department returns to place choice without loading businesses',
      (tester) async {
    final backend = ReadyBackend();
    final service = DirectoryService(backend: backend);
    DirectoryUseSelection? choice;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      choice = await Navigator.of(context)
                          .push<DirectoryUseSelection>(MaterialPageRoute(
                              builder: (_) =>
                                  DirectoryPage(directory: service)));
                    },
                    child: const Text('Ouvrir'))))));
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('75 · Paris'), findsOneWidget);
    expect(backend.queries, 0);
    await tester
        .ensureVisible(find.byKey(const ValueKey('use-territory-fr-75')));
    await tester.tap(find.byKey(const ValueKey('use-territory-fr-75')));
    await tester.pumpAndSettle();
    expect(choice!.pack.id, 'fr-75');
    expect(choice!.seed, isNull);
    expect(backend.queries, 0);
  });
}
