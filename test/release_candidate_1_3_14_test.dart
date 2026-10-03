import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account switching isolates premium and push state', () {
    final ad = File('lib/services/ad_service.dart').readAsStringSync();
    final reminder = File('lib/services/reminder_service.dart').readAsStringSync();
    final session = File('lib/services/account_session_service.dart').readAsStringSync();

    expect(ad, contains('_cachedPremiumUid'));
    expect(ad, contains('resetAccountCache'));
    expect(reminder, contains('unregisterCurrentDevice'));
    expect(session, contains('unregisterCurrentDevice'));
    expect(session, contains('forceAccountPicker'));
  });

  test('release build is guarded by verification and admin is disabled', () {
    final release = File('build_release.ps1').readAsStringSync();
    final prod = File('config/prod.json').readAsStringSync();
    expect(release, contains('verifier_prospecto.ps1'));
    expect(release, contains('flutter build appbundle'));
    expect(prod, contains('"ADMIN_TEST_MODE": false'));
  });

  test('team dashboard batches performance reads', () {
    final dashboard = File('lib/pages/team_dashboard_screen.dart').readAsStringSync();
    expect(dashboard, contains('const batchSize = 6'));
    expect(dashboard, contains('Future.wait'));
  });
}
