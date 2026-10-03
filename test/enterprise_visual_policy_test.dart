import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ai_prospect_gps/providers/theme_provider.dart';
import 'package:ai_prospect_gps/sales/enterprise_home.dart';
import 'package:ai_prospect_gps/sales/enterprise_display.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/enterprise_workspace.dart';
import 'package:ai_prospect_gps/sales/enterprise_comparison.dart';
import 'package:ai_prospect_gps/sales/sales_editor.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'enterprise_fixture.dart';

EnterpriseSnapshot withDisplay(EnterpriseDisplaySettings display,
    {List<SalesDeal>? deals}) {
  final s = enterpriseFixture();
  return EnterpriseSnapshot(
      members: s.members,
      prospects: s.prospects,
      deals: deals ?? s.deals,
      plans: s.plans,
      appointments: s.appointments,
      invites: s.invites,
      readAt: s.readAt,
      display: display);
}

Widget shell(Widget child) => MaterialApp(
    theme: ThemeProvider().currentTheme,
    home: Scaffold(
        body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child))));
Widget overview(EnterpriseSnapshot s) => EnterpriseHomeContent(
    view: s.view(
        SalesWindow.forPeriod(enterpriseTestNow, 'week'), enterpriseTestNow),
    period: 'week',
    onPeriod: (_) {},
    onScope: (_) {},
    onProspects: (_) {},
    onDeals: (_) {},
    onActivity: (_) {},
    onComparison: () {});
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));
  test(
      'display defaults remain compatible and an empty dashboard setting is normalized',
      () {
    expect(EnterpriseDisplaySettings.fromMap(null).showRevenue, true);
    expect(
        EnterpriseDisplaySettings.fromMap(
            {'showContracts': false, 'showRevenue': false}).showContracts,
        true);
    expect(
        EnterpriseDisplaySettings.fromMap(
            {'showContracts': true, 'showRevenue': false}).showRevenue,
        false);
  });
  testWidgets(
      'contracts-only home and comparison show no revenue or missing amount messages',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = withDisplay(const EnterpriseDisplaySettings(showRevenue: false));
    await tester.pumpWidget(shell(overview(s)));
    await tester.pumpAndSettle();
    expect(find.text('Contrats'), findsOneWidget);
    expect(find.textContaining('€'), findsNothing);
    expect(find.textContaining('sans montant'), findsNothing);
    expect(find.text('Comparer les équipes'), findsOneWidget);
    await tester.pumpWidget(shell(ComparisonCard(
        name: 'Équipe A',
        uids: {'rep0', 'rep1'},
        view: s.view(SalesWindow.forPeriod(enterpriseTestNow, 'week'),
            enterpriseTestNow))));
    await tester.pumpAndSettle();
    expect(find.textContaining('€'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unknown signed amounts are not displayed as zero revenue',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final s = withDisplay(const EnterpriseDisplaySettings(), deals: [
      SalesDeal(
          id: 's',
          ownerUid: 'rep0',
          ownerName: 'Sarah',
          prospectId: 'p0',
          prospectName: 'Client',
          title: 'Projet',
          stage: 'won',
          interest: 'warm',
          closedAt: enterpriseTestNow)
    ]);
    await tester.pumpWidget(shell(overview(s)));
    await tester.pumpAndSettle();
    expect(find.text('Montants non renseignés'), findsOneWidget);
    expect(find.text('0 € HT signés'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('revenue-only choice replaces contract count card',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shell(overview(
        withDisplay(const EnterpriseDisplaySettings(showContracts: false)))));
    await tester.pumpAndSettle();
    expect(find.text('Chiffre d’affaires'), findsOneWidget);
    expect(find.text('Contrats'), findsNothing);
    expect(find.text('12 signés'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 360.0, 600.0]) {
    testWidgets(
        'read-only opportunity $width is a summary and hides money when disabled',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final d = SalesDeal(
          id: 'a',
          ownerUid: 'rep0',
          ownerName: 'Sarah',
          prospectId: 'p0',
          prospectName: 'Cabinet du docteur Joël Palacci',
          title: 'Projet énergie',
          stage: 'won',
          interest: 'hot',
          signedAt: enterpriseTestNow,
          offer: 'Contrat énergie',
          contractReference: 'REF-12',
          amountCents: 150000,
          note: 'Visite réalisée');
      await tester.pumpWidget(
          shell(OpportunityDetailContent(deal: d, showRevenue: false)));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Montant HT'), findsNothing);
      expect(find.textContaining('€'), findsNothing);
      expect(find.text('Contrat signé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'administrator five destinations fit $width with enlarged system text',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int selected = -1;
      const labels = [
        'Entreprise',
        'Prospects',
        'Équipes',
        'Planning',
        'Résultats'
      ];
      await tester.pumpWidget(MaterialApp(
          theme: ThemeProvider().currentTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 800),
                  textScaler: const TextScaler.linear(1.8)),
              child: Scaffold(
                  bottomNavigationBar: EnterpriseBottomBar(
                      labels: labels,
                      icons: const [
                        Icons.dashboard_outlined,
                        Icons.people_outline,
                        Icons.groups_outlined,
                        Icons.calendar_month_outlined,
                        Icons.insights_outlined
                      ],
                      selectedIndex: 0,
                      onSelected: (v) => selected = v)))));
      await tester.pumpAndSettle();
      for (final label in labels) {
        final t = find.text(label);
        expect(t, findsOneWidget);
        final render = tester.renderObject<RenderParagraph>(t);
        final painter = TextPainter(
            text: render.text,
            textDirection: TextDirection.ltr,
            textScaler: render.textScaler)
          ..layout(maxWidth: render.size.width);
        expect(painter.computeLineMetrics().length, 1, reason: label);
      }
      await tester.tap(find.text('Résultats'));
      expect(selected, 4);
      expect(tester.takeException(), isNull);
    });
  }
}
