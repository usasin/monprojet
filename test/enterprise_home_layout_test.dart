import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/widgets/brand_background.dart';
import 'package:ai_prospect_gps/sales/enterprise_home.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'enterprise_fixture.dart';

void main() {
  final font = Platform.environment['PROSPECTO_PREVIEW_FONT'];
  setUpAll(() async {
    if (font != null) {
      final l = FontLoader('Preview');
      l.addFont(
        Future.value(ByteData.sublistView(await File(font).readAsBytes())),
      );
      await l.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(Future.value(ByteData.sublistView(
          await File('${File(font).parent.path}/MaterialIcons-Regular.otf')
              .readAsBytes())));
      await icons.load();
    }
  });
  for (final width in [320.0, 360.0, 600.0, 1100.0]) {
    for (final scale in [1.0, 1.8]) {
      for (final dark in [false, true]) {
        testWidgets(
          'administrator overview $width / text $scale / dark $dark fits and drills into counts',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 2000));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final provider = ThemeProvider();
            if (dark) provider.toggleTheme();
            final key = GlobalKey();
            final actions = <String>[];
            final view = enterpriseFixture().view(
              SalesWindow.forPeriod(enterpriseTestNow, 'week'),
              enterpriseTestNow,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: provider.currentTheme.copyWith(
                  textTheme: provider.currentTheme.textTheme
                      .apply(fontFamily: font == null ? null : 'Preview'),
                ),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 2000),
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: BrandBackground(
                      animate: false,
                      child: SingleChildScrollView(
                        child: RepaintBoundary(
                          key: key,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: dark
                                  ? const [
                                      Color(0xFF101B2C),
                                      Color(0xFF17283A),
                                      Color(0xFF18362F)
                                    ]
                                  : const [
                                      Color(0xFFDFF2FC),
                                      Color(0xFFFFF0EE),
                                      Color(0xFFE5F6EF)
                                    ],
                            )),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: EnterpriseHomeContent(
                                view: view,
                                period: 'week',
                                onPeriod: (v) => actions.add('period:$v'),
                                onScope: (v) => actions.add('scope:$v'),
                                onProspects: (v) => actions.add('prospect:$v'),
                                onDeals: (v) => actions.add('deal:$v'),
                                onActivity: (v) => actions.add('activity:$v'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Vue entreprise'), findsOneWidget);
            expect(find.text('Portefeuille actuel'), findsOneWidget);
            expect(find.text('Ma tournée'), findsNothing);
            expect(find.text('Créer ma tournée'), findsNothing);
            await tester.tap(find.text('chauds'));
            expect(actions, contains('prospect:hot'));
            await tester.tap(find.text('Mois'));
            expect(actions, contains('period:month'));
            await tester.ensureVisible(find.text('12 signés'));
            await tester.tap(find.text('12 signés'));
            expect(actions, contains('deal:won'));
            await tester.ensureVisible(find.text('Tournées réalisées'));
            await tester.tap(find.text('Tournées réalisées'));
            expect(actions, contains('activity:plan'));
            expect(tester.takeException(), isNull);
            await tester.pumpAndSettle();
            if (Platform.environment['PROSPECTO_HOME_PREVIEW'] == '1' &&
                scale == 1) {
              await tester.runAsync(() async {
                final b = key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
                final im = await b.toImage(pixelRatio: 2);
                final bytes =
                    await im.toByteData(format: ui.ImageByteFormat.png);
                await File(
                  '${Directory.systemTemp.path}/prospecto-home-${width.toInt()}${dark ? '-dark' : ''}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                im.dispose();
              });
            }
          },
        );
      }
    }
  }
}
