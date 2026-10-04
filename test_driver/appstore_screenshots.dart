import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory(
    Platform.environment['PROSPECTO_SCREENSHOT_DIR'] ??
        'build/appstore-screenshots',
  );
  await output.create(recursive: true);
  await integrationDriver(
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
          if (image.length < 1000) return false;
          await File('${output.path}/$name.png').writeAsBytes(image);
          return true;
        },
  );
}
