import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seul OWNER gère invitations, révocations et retraits (backend)', () {
    final src = File('functions/src/index.ts').readAsStringSync();
    expect(src.contains('async function requireOwner('), isTrue);
    for (final fn in ['createOrgInvite', 'removeOrgMember', 'revokeOrgInvite']) {
      final start = src.indexOf('export const $fn');
      expect(start, greaterThanOrEqualTo(0));
      final body = src.substring(start, start + 1400);
      expect(body.contains('requireOwner('), isTrue, reason: fn);
    }
  });

  test('invitation : prénom, nom et e-mail obligatoires, e-mail vérifié', () {
    final src = File('functions/src/index.ts').readAsStringSync();
    expect(src.contains('personName(request.data?.firstName'), isTrue);
    expect(src.contains('personName(request.data?.lastName'), isTrue);
    expect(src.contains('email_verified'), isTrue);
    expect(src.contains('Cette invitation est réservée à'), isTrue);
  });

  test('les règles Firestore isolent les commerciaux', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(
      rules.contains(
        "match /{document=**} {\n          allow read: if teamRole(appId, orgId) in ['OWNER', 'MANAGER'];",
      ),
      isTrue,
    );
    expect(
      rules.contains("allow read: if teamRole(appId, orgId) == 'OWNER';"),
      isTrue,
    );
  });

  test('fenêtre Inviter : champs libérés par le State, aucun dispose après await', () {
    final members = File('lib/pages/org_members_screen.dart').readAsStringSync();
    expect(members.contains('class _InviteDialog extends StatefulWidget'), isTrue);
    expect(members.contains('emailCtrl.dispose();\n    if (result == null'), isFalse);
    expect(members.contains("labelText: 'Prénom'.tr()"), isTrue);
    expect(members.contains("labelText: 'Nom'.tr()"), isTrue);
  });

  test('dialogue Attribuer une tournée : défilant et adapté au clavier', () {
    final dash = File('lib/pages/team_dashboard_screen.dart').readAsStringSync();
    expect(dash.contains('media.viewInsets.bottom'), isTrue);
    expect(dash.contains('scrollable: true'), isTrue);
  });

  test('périmètre d\'équipe : rattachement explicite managerUid', () {
    final src = File('functions/src/index.ts').readAsStringSync();
    expect(src.contains('export const setMemberManager'), isTrue);
    expect(src.contains('requireTeamManager(appId, orgId, uid, memberUid)'), isTrue);
    expect(src.contains('Ce commercial ne fait pas partie de votre équipe.'), isTrue);

    final rules = File('firestore.rules').readAsStringSync();
    expect(rules.contains('function canReadMemberData('), isTrue);
    expect(rules.contains('allow read: if canReadMemberData(appId, orgId, memberUid);'), isTrue);
    expect(
      rules.contains("match /activity/{activityId} {\n          allow read: if teamRole(appId, orgId) == 'OWNER';"),
      isTrue,
    );

    final dash = File('lib/pages/team_dashboard_screen.dart').readAsStringSync();
    expect(dash.contains('m.managerUid == scopeUid'), isTrue);
  });
}
