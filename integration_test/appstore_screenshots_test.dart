import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ai_prospect_gps/providers/org_provider.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/sales/enterprise_workspace.dart';
import '../test/appstore_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Capture actual Prospecto widgets on an Apple simulator', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    await initializeDateFormatting('fr_FR');
    final controller = captureController();
    await controller.refresh();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('fr')],
        path: 'assets/translations',
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
    await binding.takeScreenshot('01-vue-entreprise');
    await tester.tap(find.text('Prospects').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Atelier Horizon'), findsOneWidget);
    await binding.takeScreenshot('02-portefeuille');
    await tester.tap(find.text('Atelier Horizon'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await binding.takeScreenshot('03-fiche-prospect');
  });
}
