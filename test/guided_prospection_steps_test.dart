import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/prospect_search_form.dart';

void main() {
  Future<void> mountForm(WidgetTester tester, {
    required TextEditingController address,
    required TextEditingController activities,
    required bool showZone,
    required bool showTargeting,
    required void Function() onSearch,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: ProspectSearchForm(
          showZone: showZone,
          showTargeting: showTargeting,
          addressController: address,
          activityController: activities,
          quickActivities: const ['restaurant', 'CHR', 'industrie'],
          installedTerritories: const [],
          busy: false,
          locating: false,
          offlineSupported: true,
          radiusIndex: 1,
          onRadiusChanged: (_) {},
          onActivityToggle: (value) => activities.text =
              toggleProspectActivity(activities.text, value),
          onChooseAddress: () {},
          onUsePosition: () {},
          onManageTerritories: () {},
          onSearch: onSearch,
          onOptimize: () {},
        ),
      )),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('zone is address-first without packs or technical details', (tester) async {
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    var searches = 0;
    await mountForm(tester, address: address, activities: activities,
      showZone: true, showTargeting: false, onSearch: () => searches++);
    expect(find.byKey(const Key('prospect-search-address')), findsOneWidget);
    expect(find.byKey(const Key('choose-search-address')), findsOneWidget);
    expect(find.byKey(const Key('use-search-position')), findsOneWidget);
    expect(find.text('Recherche en ligne'), findsNothing);
    expect(find.text('Aucun pack installé'), findsNothing);
    expect(find.text('Mes zones'), findsNothing);
    expect(find.byKey(const Key('run-prospect-search')), findsNothing);
    expect(find.byKey(const Key('compact-activity-picker')), findsNothing);
    expect(searches, 0);
  });

  testWidgets('optional activity and radius appear separately and never search on chip', (tester) async {
    final address = TextEditingController();
    final activities = TextEditingController();
    addTearDown(address.dispose);
    addTearDown(activities.dispose);
    var searches = 0;
    await mountForm(tester, address: address, activities: activities,
      showZone: false, showTargeting: true, onSearch: () => searches++);
    expect(find.byKey(const Key('prospect-search-address')), findsNothing);
    expect(find.text('Facultatif'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('activity-restaurant')));
    await tester.tap(find.byKey(const ValueKey('activity-restaurant')));
    await tester.pumpAndSettle();
    expect(activities.text, 'restaurant');
    expect(searches, 0);
    await tester.ensureVisible(find.byKey(const Key('run-prospect-search')));
    await tester.tap(find.byKey(const Key('run-prospect-search')));
    expect(searches, 1);
  });
}
