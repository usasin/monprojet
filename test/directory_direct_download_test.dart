import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_service.dart';
import 'package:ai_prospect_gps/directory/directory_page.dart';
import 'package:ai_prospect_gps/services/prospecto_directory_api.dart';

class DownloadBackend extends Fake implements DirectoryBackend {
  final downloaded = <DirectoryPack>[];
  final finish = Completer<void>();
  DirectoryPack? requested;
  @override
  bool get supported => true;
  @override
  Future<List<DirectoryPack>> installed() async => downloaded.toList();
  @override
  Future<void> install(DirectoryPack pack,
      {String? localFile, List<int>? bytes}) async {
    expect(localFile, isNull);
    expect(bytes, isNull);
    requested = pack;
    await finish.future;
    downloaded.add(pack);
  }
}

void main() {
  testWidgets('catalog loads automatically and download stays inside the app',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = DownloadBackend();
    final api = ProspectoDirectoryApi('https://directory.example',
        client: MockClient((request) async {
      expect(request.url.path, '/v1/catalog');
      return http.Response(
          File('test/fixtures/prospecto_api_catalog.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await tester.pumpWidget(MaterialApp(
        home: DirectoryPage(
            directory: DirectoryService(backend: backend), api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('territoire(s) disponibles'), findsOneWidget,
        reason: tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(' | '));
    expect(find.text('Choisir la liste des départements'), findsNothing);
    expect(find.text('Charger le fichier du territoire'), findsNothing);
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
    await tester.pump();
    expect(backend.requested!.url!.host, 'directory.example');
    expect(
        find.text('Téléchargement et vérification en cours…'), findsOneWidget);
    backend.finish.complete();
    await tester.pumpAndSettle();
    expect(find.text('Téléchargement et vérification en cours…'), findsNothing);
    expect(find.byKey(const ValueKey('use-territory-fr-75')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('energy is absent from the public establishment sheet',
      (tester) async {
    final catalog = jsonDecode(
            File('test/fixtures/prospecto_api_catalog.json').readAsStringSync())
        as Map<String, dynamic>;
    final row = (jsonDecode(File('test/fixtures/prospecto_api_search.json')
            .readAsStringSync())['results'] as List)
        .first as Map;
    final pack = parseDirectoryCatalog(catalog).single;
    final result = await ProspectoDirectoryApi('https://directory.example',
        client: MockClient((_) async =>
            http.Response(
                File('test/fixtures/prospecto_api_search.json')
                    .readAsStringSync(),
                200,
                headers: {
                  'content-type': 'application/json; charset=utf-8'
                }))).searchNearby(
        lat: 48.86, lng: 2.33, radiusMeters: 2000, query: 'restaurant');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DirectoryDetails(
                record: DirectoryRecord(result.places.first,
                    Map<String, Object?>.from(row), [], pack)))));
    await tester.tap(find.text('Fiche établissement'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SIRET :'), findsOneWidget);
    expect(find.textContaining('Énergie'), findsNothing);
    expect(find.textContaining('Consommation'), findsNothing);
  });
}
