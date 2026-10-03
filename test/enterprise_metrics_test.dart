import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/models/route_metrics.dart';

void main() {
  test('Empty week has no completion percentage', () {
    final metrics = RouteMetrics.fromPlans([]);
    expect(metrics.completionRate, isNull);
    expect(metrics.remaining, 0);
  });
  test('Placeholder reports and orphan reports do not count as visits', () {
    final metrics = RouteMetrics.fromPlans([
      {
        'prospectIds': ['a', 'b', 'c', 'a'],
        'reports': {
          'a': {'status': 'présent'},
          'b': {'status': 'vide'},
          'c': {},
          'orphan': {'status': 'rdv'},
        }
      },
      {
        'prospectIds': ['a'],
        'reports': {
          'a': {'status': 'absent'}
        }
      },
    ]);
    expect(metrics.planned, 4);
    expect(metrics.completed, 2);
    expect(metrics.routes, 2);
    expect(metrics.remaining, 2);
    expect(metrics.completionRate, .5);
    expect(metrics.statuses, {'présent': 1, 'absent': 1});
  });
}
