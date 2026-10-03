import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home does not repeat workspace identity inside the hero card', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final heroStart = home.indexOf('class _GlassHeroCard');
    expect(heroStart, greaterThanOrEqualTo(0));
    final hero = home.substring(heroStart);
    expect(hero.contains('const WorkspaceBadge()'), isFalse);
    expect(home.contains("'Équipe & accès'"), isTrue);
    expect(home.contains("'Planning partagé'"), isTrue);
    expect(home.contains("'Performance terrain'"), isTrue);
  });

  test('personal badge uses the account avatar and company badge uses company avatar', () {
    final badge = File('lib/widgets/workspace_badge.dart').readAsStringSync();
    expect(badge.contains('AccountAvatar('), isTrue);
    expect(badge.contains('CompanyAvatar('), isTrue);
  });

  test('settings separates enterprise administration from preferences', () {
    final settings = File('lib/pages/settings_screen.dart').readAsStringSync();
    expect(settings.contains("? 'Entreprise'"), isTrue);
    expect(settings.contains("'Membres & invitations'"), isTrue);
    expect(settings.contains("title: 'Identité & logo'"), isTrue);
    expect(settings.contains('_pickAccountPhoto'), isTrue);
  });

  // Responsive invitation behavior is exercised in enterprise_dialogs_test.dart.
}
