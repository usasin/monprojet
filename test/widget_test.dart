import 'package:flutter_test/flutter_test.dart';

import 'package:ai_prospect_gps/theme/prospecto_colors.dart';

void main() {
  test('la palette Prospecto/CIP est disponible', () {
    expect(ProspectoColors.blue.value, 0xFF5AACDB);
    expect(ProspectoColors.green.value, 0xFF3CC398);
    expect(ProspectoColors.peach.value, 0xFFFBA49B);
  });
}
