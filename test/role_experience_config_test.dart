import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('team home exposes role-specific 2026 cockpit', () {
    final source =
        File('lib/widgets/role_home_dashboard.dart').readAsStringSync();
    expect(source.contains('Votre entreprise, en un coup d’œil.'), isTrue);
    expect(source.contains('Votre équipe, prête pour le terrain.'), isTrue);
    expect(
        source.contains('Votre journée commerciale, sans dispersion.'), isTrue);
    expect(source.contains('Centre de pilotage'), isTrue);
    expect(source.contains('PRIORITÉ MAINTENANT'), isTrue);
  });

  test('team dashboard accepts direct tab navigation', () {
    final source =
        File('lib/pages/team_dashboard_screen.dart').readAsStringSync();
    expect(
        source.contains('ModalRoute.of(context)?.settings.arguments'), isTrue);
    expect(source.contains('initialIndex: initialTab'), isTrue);
  });

  test('shared team prospect deletion is server-controlled and owner-only', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(
      rules.contains(
        "match /prospects/{prospectId} {\n          allow read, create, update: if teamMember(appId, orgId);\n          allow delete: if false;",
      ),
      isTrue,
    );

    final reporting = File('lib/pages/reporting_page.dart').readAsStringSync();
    expect(reporting.contains('!org.isTeam || org.isOwner'), isTrue);
    expect(reporting.contains('if (widget.onDelete != null)'), isTrue);
  });
}
