import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/sales/sales_insights.dart';

void main() {
  for (final width in [320.0, 600.0, 1100.0]) {
    testWidgets('sales metrics fit width $width with enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1200),
                textScaler: const TextScaler.linear(1.8),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SalesMetricGrid(
                    items: [
                      SalesMetric(
                        'Affaires chaudes',
                        '42',
                        Icons.local_fire_department_outlined,
                        () => taps++,
                      ),
                      SalesMetric(
                        'Relances en retard',
                        '18',
                        Icons.notifications_outlined,
                        () {},
                      ),
                      SalesMetric(
                        'Contrats signés',
                        '7',
                        Icons.check_circle_outline,
                        () {},
                      ),
                      SalesMetric(
                        'Taux de gain',
                        '58 %',
                        Icons.insights_outlined,
                        () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Affaires chaudes'));
      expect(taps, 1);
    });
  }
}
