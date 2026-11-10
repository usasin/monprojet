import 'package:ai_prospect_gps/services/osm_search_service.dart';
import 'package:ai_prospect_gps/widgets/osm_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<OSMGeoPoint?>? selection;

  Future<void> openPicker(WidgetTester tester, OSMGeocodeResult result) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () {
                    selection = chooseOSMLocation(context, result);
                  },
                  child: const Text('Search'),
                )),
      ),
    ));
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('a unique exact city remains usable without another action',
      (tester) async {
    final city = OSMGeoPoint(43.296, 5.37, displayName: 'Marseille, France');
    await openPicker(
        tester,
        OSMGeocodeResult(
          options: [city],
          queryUsed: 'Marseille',
          isFallback: false,
        ));
    expect(find.byType(AlertDialog), findsNothing);
    expect(await selection, same(city));
  });

  testWidgets('a less precise fallback requires explicit acceptance',
      (tester) async {
    final city = OSMGeoPoint(43.296, 5.37, displayName: 'Marseille, France');
    await openPicker(
        tester,
        OSMGeocodeResult(
          options: [city],
          queryUsed: 'Marseille',
          isFallback: true,
        ));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Marseille, France'));
    await tester.pumpAndSettle();
    expect(await selection, same(city));
  });

  testWidgets('ambiguous places can be cancelled without choosing a centre',
      (tester) async {
    await openPicker(
        tester,
        OSMGeocodeResult(
          options: [
            OSMGeoPoint(48.85, 2.35, displayName: 'Paris, France'),
            OSMGeoPoint(33.66, -95.55, displayName: 'Paris, Texas, USA'),
          ],
          queryUsed: 'Paris',
          isFallback: false,
        ));
    expect(find.text('Paris, Texas, USA'), findsOneWidget);
    // Back has the same cancellation semantics as the visible cancel button.
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    expect(await selection, isNull);
  });

  testWidgets('the chosen international candidate is returned unchanged',
      (tester) async {
    final texas = OSMGeoPoint(33.66, -95.55, displayName: 'Paris, Texas, USA');
    await openPicker(
        tester,
        OSMGeocodeResult(
          options: [
            OSMGeoPoint(48.85, 2.35, displayName: 'Paris, France'),
            texas
          ],
          queryUsed: 'Paris',
          isFallback: false,
        ));
    await tester.tap(find.text('Paris, Texas, USA'));
    await tester.pumpAndSettle();
    expect(await selection, same(texas));
  });

  testWidgets('long place labels remain scrollable on a narrow enlarged screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
      child: OSMLocationPicker(
          result: OSMGeocodeResult(
        options: List.generate(
            5,
            (i) => OSMGeoPoint(51.5, -0.12,
                displayName:
                    'Candidate $i, Westminster, Greater London, England, United Kingdom')),
        queryUsed: 'London',
        isFallback: true,
      )),
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
