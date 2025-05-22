import '../models/prospect.dart';

class RoutePlanner {
  Future<List<Prospect>> buildDailyRoute(
      DateTime date, int maxVisites, List<Prospect> tous) async {
    final candidats = tous.where((p) =>
    p.prochaineVisite == null ||
        _isSameDay(p.prochaineVisite!, date)).toList();
    return candidats.take(maxVisites).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

