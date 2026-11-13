import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/prospect_search_form.dart';
import 'package:ai_prospect_gps/services/prospect_location_service.dart';
import 'package:ai_prospect_gps/widgets/prospect_location_chooser.dart';
import 'package:ai_prospect_gps/widgets/prospect_info_chip.dart';

void main() {
  test('technical diagnostics become short user-facing explanations', () {
    final message = prospectSearchSourceExplanation(
      'Zone sans pack complet : complément en ligne.', isFrench: true);
    expect(message, contains('Internet'));
    expect(message, isNot(contains('pack complet')));
    expect(message, isNot(contains('OpenStreetMap')));
    final partial = prospectSearchSourceExplanation(
      'Source indisponible : Overpass', isFrench: true);
    expect(partial, contains('incomplète'));
    expect(partial, isNot(contains('Overpass')));
  });

  test('activity toggles preserve other selected and custom activities', () {
    expect(
        toggleProspectActivity(
            'restaurant, hôtel, grossiste textile', 'restaurant'),
        'hôtel, grossiste textile');
    expect(toggleProspectActivity('restaurant', 'hôtel'), 'restaurant, hôtel');
    expect(toggleProspectActivity('Hôtel', 'hotel'), '');
    expect(prospectActivityTokens('restaurant | hôtel; industrie'),
        ['restaurant', 'hôtel', 'industrie']);
  });

  testWidgets('compact activities expand, keep custom keywords and never auto-search',
      (tester) async {
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    var searches = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProspectSearchForm(
            addressController: address,
            activityController: activities,
            quickActivities: const [
              'restaurant', 'hôtel', 'pharmacie', 'garage', 'industrie',
              'logistique', 'grossiste boissons',
            ],
            installedTerritories: const [],
            busy: false,
            locating: false,
            offlineSupported: false,
            radiusIndex: 1,
            onRadiusChanged: (_) {},
            onActivityToggle: (name) =>
                activities.text = toggleProspectActivity(activities.text, name),
            onChooseAddress: () {},
            onUsePosition: () {},
            onManageTerritories: () {},
            onSearch: () => searches++,
            onOptimize: () {},
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('activity-logistique')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('show-all-activities')));
    await tester.tap(find.byKey(const Key('show-all-activities')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('activity-logistique')));
    await tester.tap(find.byKey(const ValueKey('activity-logistique')));
    await tester.pump();
    expect(activities.text, 'logistique');
    await tester.ensureVisible(find.byKey(const Key('show-all-activities')));
    await tester.tap(find.byKey(const Key('show-all-activities')));
    await tester.pump();
    expect(find.byKey(const ValueKey('activity-logistique')), findsNothing);
    expect(find.byKey(const ValueKey('selected-logistique')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('show-custom-activities')));
    await tester.tap(find.byKey(const Key('show-custom-activities')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('prospect-search-activities')));
    await tester.enterText(
        find.byKey(const Key('prospect-search-activities')),
        'logistique, grossiste textile');
    await tester.pump();
    expect(activities.text, 'logistique, grossiste textile');
    expect(searches, 0);
    await tester.ensureVisible(find.byKey(const Key('clear-activities')));
    await tester.tap(find.byKey(const Key('clear-activities')));
    await tester.pump();
    expect(activities.text, isEmpty);
    expect(searches, 0);
    await tester.ensureVisible(find.byKey(const Key('show-custom-activities')));
    await tester.tap(find.byKey(const Key('show-custom-activities')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prospect-search-activities')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('run-prospect-search')));
    await tester.tap(find.byKey(const Key('run-prospect-search')));
    expect(searches, 1);
  });

  testWidgets(
      'multiple activity choices and GPS only prepare form; Search is explicit',
      (tester) async {
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    var searches = 0, gps = 0, lookups = 0, territories = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProspectSearchForm(
                    addressController: address,
                    activityController: activities,
                    quickActivities: const ['restaurant', 'hôtel'],
                    installedTerritories: const ['75 · Paris'],
                    busy: false,
                    locating: false,
                    offlineSupported: true,
                    radiusIndex: 1,
                    onRadiusChanged: (_) {},
                    onActivityToggle: (value) => activities.text =
                        toggleProspectActivity(activities.text, value),
                    onChooseAddress: () => lookups++,
                    onUsePosition: () => gps++,
                    onManageTerritories: () => territories++,
                    onSearch: () => searches++,
                    onOptimize: () {})))));
    await tester
        .ensureVisible(find.byKey(const ValueKey('activity-restaurant')));
    await tester.tap(find.byKey(const ValueKey('activity-restaurant')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('activity-hotel')));
    await tester.pump();
    expect(activities.text, 'restaurant, hôtel');
    expect(
        tester
            .widget<FilterChip>(
                find.byKey(const ValueKey('activity-restaurant')))
            .selected,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('activity-restaurant')));
    await tester.pump();
    expect(activities.text, 'hôtel');
    expect(searches, 0);
    await tester.ensureVisible(find.byKey(const Key('use-search-position')));
    await tester.tap(find.byKey(const Key('use-search-position')));
    expect(gps, 1);
    expect(searches, 0);
    await tester.tap(find.byKey(const Key('choose-search-address')));
    expect(lookups, 1);
    expect(searches, 0);
    await tester.ensureVisible(find.byKey(const Key('run-prospect-search')));
    await tester.tap(find.byKey(const Key('run-prospect-search')));
    expect(searches, 1);
  });

  testWidgets('small screen and large text remain scrollable without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 720), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ProspectSearchForm(
                        addressController: address,
                        activityController: activities,
                        quickActivities: const [
                          'restaurant',
                          'hôtel',
                          'grossiste boissons'
                        ],
                        installedTerritories: const ['13 · Bouches-du-Rhône'],
                        selectedTerritory: '13 · Bouches-du-Rhône',
                        selectedLocation: '10 rue très longue, 13001 Marseille',
                        busy: false,
                        locating: false,
                        offlineSupported: true,
                        radiusIndex: 1,
                        onRadiusChanged: (_) {},
                        onActivityToggle: (_) {},
                        onChooseAddress: () {},
                        onUsePosition: () {},
                        onManageTerritories: () {},
                        onSearch: () {},
                        onOptimize: () {}))))));
    await tester.ensureVisible(find.byKey(const Key('run-prospect-search')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'busy location or query disables search and repeated location requests',
      (tester) async {
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProspectSearchForm(
                    addressController: address,
                    activityController: activities,
                    quickActivities: const ['restaurant'],
                    installedTerritories: const [],
                    busy: false,
                    locating: true,
                    offlineSupported: true,
                    radiusIndex: 1,
                    onRadiusChanged: (_) {},
                    onActivityToggle: (_) {},
                    onChooseAddress: () {},
                    onUsePosition: () {},
                    onManageTerritories: () {},
                    onSearch: () {},
                    onOptimize: () {})))));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('run-prospect-search')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const Key('use-search-position')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('prospect-search-address')))
            .enabled,
        isFalse);
  });

  testWidgets('even a single address is explicitly accepted by the user',
      (tester) async {
    ProspectSearchLocation? selected;
    const candidate = ProspectSearchLocation(
        label: 'Rue de Rivoli 75001 Paris',
        lat: 48.86,
        lon: 2.33,
        kind: 'street');
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      selected =
                          await chooseProspectLocation(context, [candidate]);
                    },
                    child: const Text('Choisir'))))));
    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.text('Rue de Rivoli 75001 Paris'), findsOneWidget);
    await tester.tap(find.text('Rue de Rivoli 75001 Paris'));
    await tester.pumpAndSettle();
    expect(selected, same(candidate));
  });

  if (const bool.fromEnvironment('PROSPECTO_CAPTURE_UI')) {
    testWidgets('capture actual guided search form', (tester) async {
      tester.view.physicalSize = const Size(420, 1120);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = File('C:/Windows/Fonts/arial.ttf').readAsBytesSync();
      final fonts = FontLoader('ProspectoPreview')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await tester.runAsync(() => fonts.load());
      final iconBytes =
          File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf')
              .readAsBytesSync();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await tester.runAsync(() => icons.load());
      final address =
          TextEditingController(text: '10 Rue de Rivoli 75004 Paris');
      final activities = TextEditingController(text: 'restaurant, hôtel');
      addTearDown(address.dispose);
      addTearDown(activities.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'ProspectoPreview',
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xff3cc398))),
          home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                  backgroundColor: const Color(0xfff6faff),
                  appBar:
                      AppBar(title: const Text('Trouver des professionnels')),
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ProspectSearchForm(
                          addressController: address,
                          activityController: activities,
                          quickActivities: const [
                            'restaurant',
                            'café',
                            'hôtel',
                            'GMS',
                            'pharmacie',
                            'logistique',
                            'industrie',
                            'grossiste boissons'
                          ],
                          installedTerritories: const ['75 · Paris'],
                          selectedTerritory: '75 · Paris',
                          selectedLocation: address.text,
                          busy: false,
                          locating: false,
                          offlineSupported: true,
                          radiusIndex: 2,
                          onRadiusChanged: (_) {},
                          onActivityToggle: (_) {},
                          onChooseAddress: () {},
                          onUsePosition: () {},
                          onManageTerritories: () {},
                          onSearch: () {},
                          onOptimize: () {}))))));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('../../outputs/Prospecto_APERCU_RECHERCHE_GUIDEE.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }
}
