import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
      // Widget layout can finish before iOS presents the new Metal surface.
      // A native capture taken immediately can still show "Test starting…".
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(seconds: 1));
        });
        final bytes = await binding.takeScreenshot(name);
        if (await hasRenderedLightScreen(bytes)) return;
      }
      fail('Native capture $name still shows a black startup surface.');
    });
  });
}

// This fixture always uses the light theme. Inspect native pixels as well as
// widget finders: a successfully laid-out tree is not proof of a rendered image.
Future<bool> hasRenderedLightScreen(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  try {
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (data == null) return false;
    var sampled = 0, lit = 0;
    for (var y = 0; y < frame.image.height; y += 32) {
      for (var x = 0; x < frame.image.width; x += 32) {
        final index = (y * frame.image.width + x) * 4;
        sampled++;
        if (data.getUint8(index) > 80 &&
            data.getUint8(index + 1) > 80 &&
            data.getUint8(index + 2) > 80) {
          lit++;
        }
      }
    }
    return lit > sampled / 2;
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}
