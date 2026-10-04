import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appstore_capture_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final size in [const Size(440, 956), const Size(1032, 1376)]) {
    testWidgets('capture navigation reaches all four Apple screens at $size', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.binding.setSurfaceSize(size);
      try {
        final translations =
            jsonDecode(File('assets/translations/fr.json').readAsStringSync())
                as Map<String, dynamic>;
        final captured = <String>[];
        await captureAppStoreFlow(tester, translations, (name) async {
          captured.add(name);
          expect(tester.takeException(), isNull);
        });
        expect(captured, [
          '01-vue-entreprise',
          '02-portefeuille',
          '03-fiche-prospect',
          '04-acces-premium',
        ]);
        expect(find.text('Voir les offres Premium'), findsOneWidget);
        expect(find.text('J’ai un code d’entreprise'), findsOneWidget);
        expect(find.textContaining('Stripe'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        await tester.binding.setSurfaceSize(null);
      }
    });
  }
}
