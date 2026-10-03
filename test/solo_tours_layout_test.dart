import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ai_prospect_gps/sales/solo_tours.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  for (final width in [320.0, 600.0, 1100.0]) {
    testWidgets('saved solo tour expands without overflowing at $width',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = FakeFirebaseFirestore();
      await db.doc('users/tester/plans/2026-10-02').set({
        'prospectIds': ['a', 'b', 'c']
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 1000), textScaler: const TextScaler.linear(1.8)),
        child: SoloTours(firestore: db, userUid: 'tester'),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('3 visites'), findsOneWidget);
      await tester.tap(find.text('3 visites'));
      await tester.pumpAndSettle();
      expect(find.text('Carte'), findsOneWidget);
      expect(find.text('Compte rendu'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
