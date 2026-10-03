import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:ai_prospect_gps/widgets/invite_member_dialog.dart';
import 'package:ai_prospect_gps/pages/team_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  for (final size in [const Size(344, 740), const Size(740, 600)]) {
    testWidgets('Invitation fits $size with keyboard and disposes after close',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const InviteMemberDialog(managers: {
                              'm': 'Responsable avec un nom très long'
                            })),
                    child: const Text('Ouvrir'),
                  )))));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Créer le code'));
      await tester.tap(find.text('Créer le code'));
      await tester.pumpAndSettle();
      expect(find.text('Champ obligatoire'), findsNWidgets(2));
      expect(find.text('Adresse e-mail valide requise'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Tour assignment scrolls in a wide Fold viewport with keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(740, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('fr')],
        path: 'assets/translations',
        assetLoader: const _TestLoader(),
        startLocale: const Locale('fr'),
        child: Builder(
            builder: (context) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: Builder(
                      builder: (context) => Scaffold(
                              body: TextButton(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => AssignTourDialog(
                                    orgId: 'test', firestore: db)),
                            child: const Text('Ouvrir'),
                          ))),
                ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _TestLoader extends AssetLoader {
  const _TestLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) =>
      SynchronousFuture(<String, dynamic>{});
}
