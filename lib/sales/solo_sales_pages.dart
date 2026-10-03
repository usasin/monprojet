import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';
import 'sales_insights.dart';
import 'sales_portfolio.dart';

/// Solo keeps its own home and Reporting; sales are complementary pages.
class SoloProspectsPage extends StatelessWidget {
  const SoloProspectsPage({super.key});
  static const routeName = '/solo_prospects';
  @override
  Widget build(BuildContext context) => const _SoloPage(
        title: 'Mes prospects',
        child: SalesPortfolio(orgId: ''),
      );
}

class SoloSalesResultsPage extends StatelessWidget {
  const SoloSalesResultsPage({super.key});
  static const routeName = '/solo_sales_results';
  @override
  Widget build(BuildContext context) => const _SoloPage(
        title: 'Contrats & résultats',
        child: SalesInsights(),
      );
}

class _SoloPage extends StatelessWidget {
  const _SoloPage({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    return Theme(
      data: theme,
      child: BrandBackground(
        animate: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(title),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SafeArea(top: false, child: child),
        ),
      ),
    );
  }
}
