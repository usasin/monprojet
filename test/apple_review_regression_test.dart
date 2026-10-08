import 'dart:async';

import 'package:ai_prospect_gps/pages/login_screen.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/screens/credits_paywall_page.dart';
import 'package:ai_prospect_gps/services/in_app_purchase_service.dart';
import 'package:ai_prospect_gps/services/usage_meter.dart';
import 'package:ai_prospect_gps/widgets/apple_sign_in_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// Fake the existing IAP platform without adding a runtime dependency.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_localization.dart';

class FakeStore extends InAppPurchasePlatform {
  final events = StreamController<List<PurchaseDetails>>.broadcast();
  Future<bool> Function() availability = () async => true;
  Future<ProductDetailsResponse> Function(Set<String>) catalogue =
      (_) async => ProductDetailsResponse(productDetails: [], notFoundIDs: []);
  int restoreCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<bool> isAvailable() => availability();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      catalogue(ids);
  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
    await Completer<void>().future;
  }
}

class OfflineMeter implements UsageMeter {
  Future<void>? pending;
  @override
  Future<void> initIfNeeded() async {}
  @override
  Future<void> syncFromCloud({bool forceRefresh = false}) async {
    if (pending != null) return pending!;
    throw StateError('Cloud unavailable');
  }

  @override
  Future<bool> isPremium() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CancelledAppleAuth implements FirebaseAuth {
  AuthProvider? requestedProvider;
  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    requestedProvider = provider;
    throw FirebaseAuthException(code: 'canceled');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductDetails product(String id, String price) => ProductDetails(
      id: id,
      title: id,
      description: 'Premium',
      price: price,
      rawPrice: 9,
      currencyCode: 'EUR',
    );

Widget localized(Widget child, {double textScale = 1}) => EasyLocalization(
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeStore store;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // Initialize the facade once, then replace only its platform for tests.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      InAppPurchase.instance;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  setUp(() {
    store = FakeStore();
    InAppPurchasePlatform.instance = store;
  });
  tearDown(() async => store.events.close());

  test(
    'an empty StoreKit response is unavailable, even without notFoundIDs',
    () async {
      final service = InAppPurchaseService(
        onDeliverPurchase: (_) async => false,
      );
      expect(await service.loadProducts(), isFalse);
      service.dispose();
    },
  );
  test('both availability and catalogue queries have a timeout', () async {
    final service = InAppPurchaseService(onDeliverPurchase: (_) async => false);
    store.availability = () => Completer<bool>().future;
    await expectLater(
      service.loadProducts(
        availabilityTimeout: const Duration(milliseconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    store.availability = () async => true;
    store.catalogue = (_) => Completer<ProductDetailsResponse>().future;
    await expectLater(
      service.loadProducts(timeout: const Duration(milliseconds: 5)),
      throwsA(isA<TimeoutException>()),
    );
    service.dispose();
  });
  test(
    'retry keeps the purchase listener and accepts only the configured products',
    () async {
      var delivered = 0;
      final service = InAppPurchaseService(
        onDeliverPurchase: (_) async {
          delivered++;
          return false;
        },
      );
      store.availability = () async => false;
      expect(await service.loadProducts(), isFalse);
      expect(store.events.hasListener, isTrue);
      store.availability = () async => true;
      store.catalogue = (_) async => ProductDetailsResponse(
            productDetails: [
              product('unrelated', '1 €'),
              product('premium_monthly', '4,99 €'),
            ],
            notFoundIDs: ['premium_yearly'],
          );
      expect(await service.loadProducts(), isTrue);
      expect(service.getProduct('unrelated'), isNull);
      expect(service.getProduct('premium_monthly')?.price, '4,99 €');
      store.events.add([
        PurchaseDetails(
          productID: 'premium_monthly',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: 'proof',
            source: 'app_store',
          ),
          transactionDate: null,
          status: PurchaseStatus.restored,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(delivered, 1);
      service.dispose();
      expect(store.events.hasListener, isFalse);
    },
  );

  testWidgets(
    'iPad shows subscription information while store and cloud are pending; no automatic restore',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      try {
        store.availability = () => Completer<bool>().future;
        final meter = OfflineMeter()..pending = Completer<void>().future;
        await tester.pumpWidget(
          localized(CreditsPaywallPage(usageMeter: meter)),
        );
        await tester.pump();
        expect(
          find.text('Débloque toutes les fonctionnalités'),
          findsOneWidget,
        );
        expect(find.text('Chargement du prix…'), findsNWidgets(2));
        expect(store.restoreCalls, 0);
        await tester.pump(const Duration(seconds: 11));
        await tester.pump();
        expect(find.text('Réessayer'), findsOneWidget);
        expect(find.text('Offre indisponible'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1180, 820),
  ]) {
    testWidgets('retry shows localized store prices at $size with large text', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      try {
        await tester.pumpWidget(
          localized(
            CreditsPaywallPage(usageMeter: OfflineMeter()),
            textScale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Réessayer'), findsOneWidget);
        store.catalogue = (_) async => ProductDetailsResponse(
              productDetails: [
                product('premium_monthly', '4,99 €'),
                product('premium_yearly', '39,99 €'),
              ],
              notFoundIDs: [],
            );
        await tester.ensureVisible(find.text('Réessayer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Réessayer'));
        await tester.pumpAndSettle();
        // Removing the error changes the scroll offset on small screens.
        await tester.drag(find.byType(ListView), const Offset(0, 1400));
        await tester.pumpAndSettle();
        expect(find.text('4,99 €'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('39,99 €'), 200);
        await tester.pumpAndSettle();
        expect(find.text('39,99 €'), findsOneWidget);
        expect(find.text('Réessayer'), findsNothing);
        expect(store.restoreCalls, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  }
  testWidgets(
    'Apple is an equivalent iOS login choice and cancellation allows retry',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final auth = CancelledAppleAuth();
        await tester.pumpWidget(
          localized(
            ChangeNotifierProvider(
              create: (_) => ThemeProvider(),
              child: LoginScreen(auth: auth),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Continuer avec Google'), findsOneWidget);
        expect(find.byType(AppleSignInButton), findsOneWidget);
        await tester.ensureVisible(find.text('Se connecter avec Apple'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Se connecter avec Apple'));
        await tester.pump();
        expect(auth.requestedProvider, isA<AppleAuthProvider>());
        expect(
          (auth.requestedProvider as AppleAuthProvider).scopes,
          containsAll(['email', 'name']),
        );
        final button = tester.widget<FilledButton>(
          find.descendant(
            of: find.byType(AppleSignInButton),
            matching: find.byType(FilledButton),
          ),
        );
        expect(button.onPressed, isNotNull);
        expect(find.textContaining('Erreur'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets('Android login keeps Google without an Apple button', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        localized(
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(),
            child: LoginScreen(auth: CancelledAppleAuth()),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Continuer avec Google'), findsOneWidget);
      expect(find.byType(AppleSignInButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
