import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace picker is scroll-safe on short screens', () {
    final badge = File('lib/widgets/workspace_badge.dart').readAsStringSync();
    expect(badge.contains('isScrollControlled: true'), isTrue);
    expect(badge.contains('useSafeArea: true'), isTrue);
    expect(badge.contains('SingleChildScrollView'), isTrue);
    expect(badge.contains('MediaQuery.viewPaddingOf(sheetContext).bottom'), isTrue);
  });

  test('developer can enter enterprise testing without Stripe', () {
    final access =
        File('lib/pages/enterprise_access_screen.dart').readAsStringSync();
    expect(access.contains('DeveloperAccessService'), isTrue);
    expect(access.contains('isDeveloper(forceRefresh: true)'), isTrue);
    expect(access.contains('isDeveloper: _isDeveloper'), isTrue);
    expect(access.contains("createActivationCode('TEAM')"), isTrue);
    expect(access.contains("'activationCode': activation.code"), isTrue);
    expect(access.contains('Tester Entreprise sans paiement'), isTrue);
    expect(access.contains('sans passer par Stripe'), isTrue);
  });
}
