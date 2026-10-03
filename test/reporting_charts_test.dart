import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/widgets/reporting_charts.dart';
import 'package:ai_prospect_gps/pages/home_page.dart';

void main() {
  final previewFont = Platform.environment['PROSPECTO_PREVIEW_FONT'];
  setUpAll(() async {
    if (previewFont != null) {
      final loader = FontLoader('ReportingPreview');
      loader.addFont(Future.value(
          ByteData.sublistView(await File(previewFont).readAsBytes())));
      await loader.load();
    }
  });
  test('Solo stays on its own home, including a legacy organization id', () {
    expect(
        HomePage.usesEnterpriseWorkspace(
            signedIn: true, isTeam: false, orgId: null),
        false);
    expect(
        HomePage.usesEnterpriseWorkspace(
            signedIn: true, isTeam: false, orgId: 'legacy'),
        false);
    expect(
        HomePage.usesEnterpriseWorkspace(
            signedIn: true, isTeam: true, orgId: 'org'),
        true);
    expect(
        HomePage.usesEnterpriseWorkspace(
            signedIn: true, isTeam: true, orgId: null),
        false);
    expect(
        HomePage.usesEnterpriseWorkspace(
            signedIn: false, isTeam: true, orgId: 'org'),
        false);
  });

  test('visit chart counts every prospect once without counting contracts', () {
    final slices = visitReportSlices(
        ['présent', 'Present', ' ABSENT ', 'rdv', null, 'vide']);
    expect(slices.map((s) => s.count).toList(), [2, 1, 1, 2]);
    expect(slices.fold(0, (n, s) => n + s.count), 6);
  });

  for (final width in [320.0, 600.0, 1100.0]) {
    testWidgets('reporting charts fit width $width and open their details',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var taps = 0;
      final previewKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            fontFamily: previewFont == null ? null : 'ReportingPreview',
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF59AAD1)),
        home: Scaffold(
            body: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 1800),
              textScaler: const TextScaler.linear(1.8)),
          child: SingleChildScrollView(
              child: RepaintBoundary(
            key: previewKey,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: ReportingChartGrid(charts: [
                  ReportingDonut(
                      title: 'Résultats des visites',
                      slices: visitReportSlices(
                          ['présent', 'absent', 'absent', 'rdv']),
                      centerLabel: 'prospects'),
                  ReportingDonut(
                      title: 'Contrats signés / perdus',
                      subtitle: 'Cette semaine',
                      centerValue: '67 %',
                      centerLabel: 'taux de gain',
                      slices: [
                        ReportSlice('Signés', 2, const Color(0xFF39BE9A),
                            onTap: () => taps++),
                        const ReportSlice('Perdus', 1, Color(0xFFEF4444)),
                      ]),
                ])),
          )),
        )),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PieChart), findsNWidgets(2));
      await tester.tap(find.text('Signés (2)'));
      expect(taps, 1);
      await tester.pumpAndSettle();
      final boundary = previewKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      if (Platform.environment['PROSPECTO_CHART_PREVIEW'] == '1')
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '${Directory.systemTemp.path}/prospecto-reporting-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
    });
  }

  testWidgets('empty chart has an honest empty state and no percentage',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ReportingDonut(
      title: 'Contrats',
      slices: [
        ReportSlice('Signés', 0, Colors.green),
        ReportSlice('Perdus', 0, Colors.red)
      ],
    ))));
    expect(find.byType(PieChart), findsNothing);
    expect(find.text('Aucune donnée sur cette période'), findsOneWidget);
    expect(find.text('0 %'), findsNothing);
  });
}
