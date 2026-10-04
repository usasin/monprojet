import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_prospect_gps/providers/org_provider.dart';
import 'package:ai_prospect_gps/widgets/workspace_badge.dart';
import 'appstore_fixture.dart';
import 'test_localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  testWidgets('signed-in identity is visible in primary navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr')],
        path: 'assets/translations',
        assetLoader: const TestTranslations(),
        startLocale: const Locale('fr'),
        saveLocale: false,
        child: ChangeNotifierProvider<OrgProvider>(
          create: (_) => CaptureOrganization(),
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: Scaffold(
                appBar: AppBar(
                  title: WorkspaceBadge(compact: true, auth: CaptureAuth()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(find.text('Équipe Horizon • Administrateur'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('settings exposes account identity and explicit account switching', () {
    final settings = File('lib/pages/settings_screen.dart').readAsStringSync();
    final session = File(
      'lib/services/account_session_service.dart',
    ).readAsStringSync();

    // L'écran doit afficher clairement le compte et proposer un changement
    // explicite de session.
    expect(settings.contains('UserIdentityCard'), isTrue);
    expect(settings.contains('Changer de compte'), isTrue);
    expect(
      settings.contains(
        'AccountSessionService.signOut(forceAccountPicker: true)',
      ),
      isTrue,
    );

    // La déconnexion Google/Firebase est volontairement centralisée dans un
    // seul service afin d'éviter des comportements différents selon l'écran.
    expect(session.contains('final google = GoogleSignIn();'), isTrue);
    // Changer de compte ne retire plus le consentement OAuth.
    expect(session.contains('await google.disconnect();'), isFalse);
    expect(session.contains('await google.signOut();'), isTrue);
    expect(session.contains('await FirebaseAuth.instance.signOut();'), isTrue);
    expect(
      session.contains('ReminderService.instance.unregisterCurrentDevice()'),
      isTrue,
    );
    expect(session.contains('AdService.instance.resetAccountCache()'), isTrue);
  });

  test('enterprise entry points show the connected identity', () {
    final access = File(
      'lib/pages/enterprise_access_screen.dart',
    ).readAsStringSync();
    final create = File('lib/pages/org_create_screen.dart').readAsStringSync();
    final join = File('lib/pages/org_join_screen.dart').readAsStringSync();
    expect(access.contains('UserIdentityCard'), isTrue);
    expect(create.contains('UserIdentityCard'), isTrue);
    expect(join.contains('UserIdentityCard'), isTrue);
  });

  test(
    'enterprise cockpit exposes the signed-in email separately from role',
    () {
      final dashboard = File(
        'lib/widgets/role_home_dashboard.dart',
      ).readAsStringSync();
      expect(dashboard.contains('user!.email!.trim()'), isTrue);
      expect(dashboard.contains('roleTitle'), isTrue);
    },
  );
}
