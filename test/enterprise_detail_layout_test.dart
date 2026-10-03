import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:ai_prospect_gps/providers/org_provider.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/models/prospect.dart';
import 'package:ai_prospect_gps/sales/enterprise_portfolio.dart';
import 'package:ai_prospect_gps/sales/enterprise_comparison.dart';
import 'package:ai_prospect_gps/sales/enterprise_display.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/sales_editor.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'enterprise_fixture.dart';

class _Org extends OrgProvider {
  @override
  bool get isTeam => true;
  @override
  bool get isOwner => true;
  @override
  String get orgId => 'company';
  @override
  EnterpriseDisplaySettings get displaySettings =>
      const EnterpriseDisplaySettings(showRevenue: false);
}

void main() {
  final font = Platform.environment['PROSPECTO_PREVIEW_FONT'];
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
    if (font != null) {
      final l = FontLoader('Preview');
      l.addFont(
          Future.value(ByteData.sublistView(await File(font).readAsBytes())));
      await l.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(Future.value(ByteData.sublistView(
          await File('${File(font).parent.path}/MaterialIcons-Regular.otf')
              .readAsBytes())));
      await icons.load();
    }
  });
  for (final width in [320.0, 360.0, 600.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
          'prospect contact card $width with text $scale remains readable',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final org = _Org();
        addTearDown(org.dispose);
        final s = enterpriseFixture();
        final view = s.view(SalesWindow.forPeriod(enterpriseTestNow, 'week'),
            enterpriseTestNow);
        final row = EnterpriseProspect(
            Prospect(
                id: 'p20',
                name: 'Cabinet du docteur Joël Palacci',
                address: '112 Avenue du Prado, Marseille',
                category: 'Santé',
                lat: 0,
                lng: 0,
                phone: '09865236523',
                email: 'contact@example.test',
                website: 'example.test',
                role: 'Gérant',
                note: 'Préparer le prochain échange avec le responsable.'),
            enterpriseTestNow,
            'rep0');
        final key = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider<OrgProvider>.value(
            value: org,
            child: MaterialApp(
                theme: ThemeProvider().currentTheme.copyWith(
                    appBarTheme: ThemeProvider().currentTheme.appBarTheme.copyWith(
                        titleTextStyle: ThemeProvider()
                            .currentTheme
                            .appBarTheme
                            .titleTextStyle
                            ?.copyWith(
                                fontFamily: font == null ? null : 'Preview')),
                    textTheme: ThemeProvider()
                        .currentTheme
                        .textTheme
                        .apply(fontFamily: font == null ? null : 'Preview')),
                home: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 1800),
                        textScaler: TextScaler.linear(scale)),
                    child: RepaintBoundary(
                        key: key,
                        child: EnterpriseProspectDetail(orgId: 'company', row: row, view: view))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Contact'), findsOneWidget);
        expect(find.text('contact@example.test'), findsOneWidget);
        expect(find.textContaining('€'), findsNothing);
        expect(find.byTooltip('Supprimer le prospect'), findsOneWidget);
        if (Platform.environment['PROSPECTO_DETAIL_PREVIEW'] == '1' &&
            scale == 1) {
          await tester.runAsync(() async {
            final im = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
            await File(
                    '${Directory.systemTemp.path}/prospecto-detail-$width.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            im.dispose();
          });
        }
      });
    }
  }
  testWidgets('opportunity and team comparison use compact visual cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = enterpriseFixture();
    final v = s.view(
        SalesWindow.forPeriod(enterpriseTestNow, 'week'), enterpriseTestNow);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeProvider().currentTheme.copyWith(
            textTheme: ThemeProvider()
                .currentTheme
                .textTheme
                .apply(fontFamily: font == null ? null : 'Preview')),
        home: Scaffold(
            body: SingleChildScrollView(
                child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                        color: const Color(0xFFE8F3F9),
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              OpportunityDetailContent(
                                  deal: s.deals.first, showRevenue: false),
                              const SizedBox(height: 16),
                              ComparisonCard(
                                  name: 'Équipe PACA',
                                  uids: {'rep0', 'rep1'},
                                  view: v)
                            ]))))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['PROSPECTO_DETAIL_PREVIEW'] == '1')
      await tester.runAsync(() async {
        final im = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
        final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
        await File(
                '${Directory.systemTemp.path}/prospecto-opportunity-comparison.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        im.dispose();
      });
  });
}
