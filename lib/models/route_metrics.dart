/// KPI based on planned stops with a non-empty saved report. Placeholder maps do
/// not count as visits. A stop is counted once per route, never once per field.
class RouteMetrics {
  RouteMetrics(this.routes, this.planned, this.completed, this.statuses);
  final int routes, planned, completed;
  final Map<String, int> statuses;
  int get remaining => planned - completed;
  double? get completionRate => planned == 0 ? null : completed / planned;
  static bool hasReport(dynamic raw) =>
      raw is Map &&
      ((!['', 'vide'].contains(raw['status']?.toString().trim() ?? '')) ||
          raw['finishedAt'] != null);

  factory RouteMetrics.fromPlans(Iterable<Map<String, dynamic>> plans) {
    var routes = 0, planned = 0, completed = 0;
    final statuses = <String, int>{};
    for (final plan in plans) {
      final ids = List<String>.from(plan['prospectIds'] ?? []).toSet();
      if (ids.isNotEmpty) routes++;
      planned += ids.length;
      final reports = Map<String, dynamic>.from(plan['reports'] ?? {});
      for (final id in ids) {
        final report = reports[id];
        if (!hasReport(report)) continue;
        completed++;
        final status = (report['status'] ?? 'Clôturé').toString();
        statuses[status] = (statuses[status] ?? 0) + 1;
      }
    }
    return RouteMetrics(routes, planned, completed, statuses);
  }
}
