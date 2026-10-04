import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_prospect_gps/pages/billing_screen.dart';
import 'test_localization.dart';

Widget localized(Widget child) => EasyLocalization(
  supportedLocales: const [Locale('fr')],
  path: 'assets/translations',
  assetLoader: const TestTranslations(),
  startLocale: const Locale('fr'),
  saveLocale: false,
  child: Builder(
    builder: (context) => MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  testWidgets(
    'iOS billing displays StoreKit and existing company access without external checkout',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(localized(const BillingScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Voir les offres Premium'), findsOneWidget);
      expect(find.text('J’ai un code d’entreprise'), findsOneWidget);
      expect(find.textContaining('Stripe'), findsNothing);
      expect(find.textContaining('Google Play'), findsNothing);
      expect(find.text('Choisir cette offre'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Apple billing routes premium and company activation to their own flows',
    (tester) async {
      var premium = 0, company = 0;
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: AppleBillingContent(
              onOpenPremium: () => premium++,
              onEnterpriseAccess: () => company++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir les offres Premium'));
      expect(premium, 1);
      expect(company, 0);
      await tester.ensureVisible(find.text('J’ai un code d’entreprise'));
      await tester.tap(find.text('J’ai un code d’entreprise'));
      expect(company, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
