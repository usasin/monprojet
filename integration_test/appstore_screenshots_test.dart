import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/appstore_capture_flow.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Capture actual Prospecto widgets on an Apple simulator', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    // Complete bundle IO outside the widget clock before mounting localization.
    // pumpAndSettle cannot wait for an asset Future that has not scheduled a frame.
    final translations = await tester.runAsync(
      () async =>
          jsonDecode(await rootBundle.loadString('assets/translations/fr.json'))
              as Map<String, dynamic>,
    );
    await captureAppStoreFlow(tester, translations!, (name) async {
      await binding.takeScreenshot(name);
    });
  });
}
