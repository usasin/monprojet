import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enterprise home always renders synchronous visible content', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    expect(source.contains("'home-team-"), isTrue);
    expect(source.contains('controller: _homeScrollController'), isTrue);
    expect(source.contains('_GlassHeroCard(isDark: isDark)'), isTrue);
    expect(source.contains('RoleHomeDashboard(org: org'), isFalse);
  });
}
