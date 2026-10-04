import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ai_prospect_gps/providers/org_provider.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/sales/enterprise_workspace.dart';
import 'package:ai_prospect_gps/pages/billing_screen.dart';
import 'appstore_fixture.dart';

class CaptureTranslations extends AssetLoader {
  const CaptureTranslations(this.translations);
  final Map<String, dynamic> translations;

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      SynchronousFuture(translations);
}

/// Run the same real navigation before native captures and in fast regression tests.
Future<void> captureAppStoreFlow(
  WidgetTester tester,
  Map<String, dynamic> translations,
  Future<void> Function(String) capture,
) async {
  await initializeDateFormatting('fr_FR');
  final navigator = GlobalKey<NavigatorState>();
  final controller = captureController();
  await controller.refresh();
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('fr')],
      path: 'assets/translations',
      assetLoader: CaptureTranslations(translations),
      startLocale: const Locale('fr'),
      saveLocale: false,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<OrgProvider>(
            create: (_) => CaptureOrganization(),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: navigator,
            theme: context.watch<ThemeProvider>().currentTheme,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: EnterpriseWorkspace(
              controller: controller,
              auth: CaptureAuth(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('Vue entreprise'), findsOneWidget);
  await capture('01-vue-entreprise');
  await tester.tap(find.text('Prospects').last);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('Atelier Horizon'), findsOneWidget);
  await capture('02-portefeuille');
  await tester.tap(find.text('Atelier Horizon'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await capture('03-fiche-prospect');
  // The prospect detail route makes EnterpriseWorkspace offstage. Use the
  // root navigator instead of looking up that hidden widget.
  navigator.currentState!.push(
    MaterialPageRoute<void>(builder: (_) => const BillingScreen()),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.text('Voir les offres Premium'), findsOneWidget);
  await capture('04-acces-premium');
}
