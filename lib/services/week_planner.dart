import 'dart:math' as math;

import '../models/prospect.dart';

/// Résultat d'une planification (lun → ven).
class WeekPlanResult {
  final DateTime monday;
  final List<List<Prospect>> days; // 5 jours: 0=lun ... 4=ven
  final List<Prospect> remaining;

  WeekPlanResult({
    required this.monday,
    required this.days,
    required this.remaining,
  });
}

class WeekPlanner {
  static DateTime toMonday(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final diff = (local.weekday - DateTime.monday) % 7;
    return local.subtract(Duration(days: diff));
  }

  /// Planifie une semaine (5 jours: lun→ven) en regroupant par secteur (géographique)
  /// et optionnellement par rues.
  static WeekPlanResult build({
    required List<Prospect> prospects,
    required DateTime monday,
    int maxPerDay = 10,
    bool modeStreet = false,
  }) {
    final mon = toMonday(monday);

    // Dedup par id
    final map = <String, Prospect>{};
    for (final p in prospects) {
      map[p.id] = p;
    }
    final pool = map.values.toList();

    // Capacité
    final cap = math.max(1, maxPerDay);

    // ✅ Version “vraiment intelligente” : regroupe par proximité (clustering)
    // Objectif : chaque jour = zone cohérente (secteur) + ordre propre (rue optionnel).
    // 1) cluster en 5 groupes (k-means light)
    // 2) rééquilibrage pour respecter cap/jour
    // 3) ordonnancement interne (rue/numéro ou nearest-neighbor)

    final clustered = modeStreet
        ? _clusterByStreet(pool, k: 5)
        : _clusterPoints(pool, k: 5);

    final days = List.generate(5, (_) => <Prospect>[]);
    final remaining = <Prospect>[];

    // clusters triés dans un ordre géographique (autour du centroïde global)
    final clusters = _sortClustersGeographically(clustered);

    // Place initialement (cap)
    final overflow = <Prospect>[];
    for (var i = 0; i < 5; i++) {
      final list = i < clusters.length ? clusters[i] : <Prospect>[];
      if (list.length <= cap) {
        days[i].addAll(list);
      } else {
        // garde les plus proches du centroïde du cluster
        final c = _centroid(list);
        list.sort((a, b) => _dist2(a, c).compareTo(_dist2(b, c)));
        days[i].addAll(list.take(cap));
        overflow.addAll(list.skip(cap));
      }
    }

    // Remplissage des jours pas pleins avec overflow (au plus proche)
    if (overflow.isNotEmpty) {
      final centroids = List.generate(5, (i) => _centroidOrFallback(days[i], pool));
      final used = <String>{};
      for (final p in overflow) {
        // trouve le meilleur jour dispo
        int best = -1;
        double bestD = double.infinity;
        for (var i = 0; i < 5; i++) {
          if (days[i].length >= cap) continue;
          final d = _dist2Point(p.lat, p.lng, centroids[i].lat, centroids[i].lng);
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        if (best == -1) break;
        if (used.add(p.id)) days[best].add(p);
      }
      // reste
      for (final p in overflow) {
        final already = days.any((d) => d.any((x) => x.id == p.id));
        if (!already) remaining.add(p);
      }
    }

    // Ordre interne
    for (var i = 0; i < 5; i++) {
      final list = days[i];
      if (list.length <= 2) continue;
      if (modeStreet) {
        final ordered = _orderByStreetThenSector(list);
        days[i]
          ..clear()
          ..addAll(ordered);
      } else {
        final ordered = _nearestNeighborOrder(list);
        days[i]
          ..clear()
          ..addAll(ordered);
      }
    }

    return WeekPlanResult(monday: mon, days: days, remaining: remaining);
  }

  /// Regroupement "secteur" : tri par angle autour du centroïde (sweep).
  static List<Prospect> _orderBySector(List<Prospect> pool) {
    if (pool.length <= 2) return List.of(pool);

    final c = _centroid(pool);
    pool.sort((a, b) {
      final aa = math.atan2(a.lat - c.lat, a.lng - c.lng);
      final bb = math.atan2(b.lat - c.lat, b.lng - c.lng);
      return aa.compareTo(bb);
    });
    return pool;
  }

  /// Ordre simple “proche en proche” (sans API) pour éviter l'effet “n'importe quoi”.
  static List<Prospect> _nearestNeighborOrder(List<Prospect> pts) {
    if (pts.length <= 2) return List.of(pts);
    final remaining = List<Prospect>.from(pts);
    // start: point le plus au nord-ouest (stable)
    remaining.sort((a, b) {
      final la = -a.lat; // desc
      final lb = -b.lat;
      if (la != lb) return la.compareTo(lb);
      return a.lng.compareTo(b.lng);
    });
    var cur = remaining.removeAt(0);
    final out = <Prospect>[cur];
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) => _dist2Point(cur.lat, cur.lng, a.lat, a.lng)
          .compareTo(_dist2Point(cur.lat, cur.lng, b.lat, b.lng)));
      cur = remaining.removeAt(0);
      out.add(cur);
    }
    return out;
  }

  /// Clustering léger (k-means) sur points.
  static List<List<Prospect>> _clusterPoints(List<Prospect> pts, {int k = 5}) {
    if (pts.isEmpty) return [];
    final kk = math.min(k, math.max(1, (pts.length / 2).round()));
    if (kk <= 1) return [List.of(pts)];

    // init centroids (k-means++ light)
    final centroids = <_Centroid>[];
    pts.sort((a, b) => a.id.compareTo(b.id)); // stable
    centroids.add(_Centroid(pts.first.lat, pts.first.lng));
    while (centroids.length < kk) {
      Prospect? best;
      double bestD = -1;
      for (final p in pts) {
        double dMin = double.infinity;
        for (final c in centroids) {
          final d = _dist2Point(p.lat, p.lng, c.lat, c.lng);
          if (d < dMin) dMin = d;
        }
        if (dMin > bestD) {
          bestD = dMin;
          best = p;
        }
      }
      if (best == null) break;
      centroids.add(_Centroid(best.lat, best.lng));
    }

    List<List<Prospect>> clusters = List.generate(centroids.length, (_) => <Prospect>[]);

    for (var iter = 0; iter < 8; iter++) {
      clusters = List.generate(centroids.length, (_) => <Prospect>[]);
      for (final p in pts) {
        var best = 0;
        var bestD = double.infinity;
        for (var i = 0; i < centroids.length; i++) {
          final c = centroids[i];
          final d = _dist2Point(p.lat, p.lng, c.lat, c.lng);
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        clusters[best].add(p);
      }

      // update
      for (var i = 0; i < centroids.length; i++) {
        if (clusters[i].isEmpty) continue;
        centroids[i] = _centroid(clusters[i]);
      }
    }
    return clusters;
  }

  /// Clustering “rue” : on cluster les groupes de rue (centroïdes de rue), puis on reconstruit.
  static List<List<Prospect>> _clusterByStreet(List<Prospect> pts, {int k = 5}) {
    if (pts.isEmpty) return [];
    final byStreet = <String, List<Prospect>>{};
    for (final p in pts) {
      final key = _streetKey(p.address);
      (byStreet[key] ??= <Prospect>[]).add(p);
    }
    final streets = byStreet.entries.toList();
    // “points” = centroid de rue
    final streetPts = <_StreetPoint>[];
    for (final e in streets) {
      final c = _centroid(e.value);
      streetPts.add(_StreetPoint(e.key, c.lat, c.lng, e.value));
    }

    // cluster sur centroid de rue
    final clustersIdx = _clusterStreetPoints(streetPts, k: k);
    // expand
    final out = <List<Prospect>>[];
    for (final cl in clustersIdx) {
      final list = <Prospect>[];
      for (final sp in cl) {
        list.addAll(sp.items);
      }
      out.add(list);
    }
    return out;
  }

  static List<List<_StreetPoint>> _clusterStreetPoints(List<_StreetPoint> pts, {int k = 5}) {
    if (pts.isEmpty) return [];
    final kk = math.min(k, math.max(1, (pts.length / 2).round()));
    if (kk <= 1) return [List.of(pts)];

    final centroids = <_Centroid>[];
    pts.sort((a, b) => a.key.compareTo(b.key));
    centroids.add(_Centroid(pts.first.lat, pts.first.lng));
    while (centroids.length < kk) {
      _StreetPoint? best;
      double bestD = -1;
      for (final p in pts) {
        double dMin = double.infinity;
        for (final c in centroids) {
          final d = _dist2Point(p.lat, p.lng, c.lat, c.lng);
          if (d < dMin) dMin = d;
        }
        if (dMin > bestD) {
          bestD = dMin;
          best = p;
        }
      }
      if (best == null) break;
      centroids.add(_Centroid(best.lat, best.lng));
    }

    List<List<_StreetPoint>> clusters = List.generate(centroids.length, (_) => <_StreetPoint>[]);

    for (var iter = 0; iter < 8; iter++) {
      clusters = List.generate(centroids.length, (_) => <_StreetPoint>[]);
      for (final p in pts) {
        var best = 0;
        var bestD = double.infinity;
        for (var i = 0; i < centroids.length; i++) {
          final c = centroids[i];
          final d = _dist2Point(p.lat, p.lng, c.lat, c.lng);
          if (d < bestD) {
            bestD = d;
            best = i;
          }
        }
        clusters[best].add(p);
      }
      for (var i = 0; i < centroids.length; i++) {
        if (clusters[i].isEmpty) continue;
        double lat = 0;
        double lng = 0;
        for (final sp in clusters[i]) {
          lat += sp.lat;
          lng += sp.lng;
        }
        centroids[i] = _Centroid(lat / clusters[i].length, lng / clusters[i].length);
      }
    }
    return clusters;
  }

  static List<List<Prospect>> _sortClustersGeographically(List<List<Prospect>> clusters) {
    if (clusters.isEmpty) return [];
    final all = clusters.expand((e) => e).toList();
    final c0 = _centroid(all);
    final indexed = <_ClusterWrap>[];
    for (final cl in clusters) {
      if (cl.isEmpty) continue;
      final cc = _centroid(cl);
      final a = math.atan2(cc.lat - c0.lat, cc.lng - c0.lng);
      indexed.add(_ClusterWrap(angle: a, items: cl));
    }
    indexed.sort((a, b) => a.angle.compareTo(b.angle));
    return indexed.map((e) => e.items).toList();
  }

  static _Centroid _centroidOrFallback(List<Prospect> pts, List<Prospect> fallback) {
    if (pts.isNotEmpty) return _centroid(pts);
    return _centroid(fallback);
  }

  static double _dist2(Prospect p, _Centroid c) => _dist2Point(p.lat, p.lng, c.lat, c.lng);

  static double _dist2Point(double la1, double lo1, double la2, double lo2) {
    final d1 = la1 - la2;
    final d2 = lo1 - lo2;
    return d1 * d1 + d2 * d2;
  }

  /// Mode "rues" :
  /// 1) group by street key
  /// 2) tri des rues par secteur (angle)
  /// 3) tri interne par numéro si possible
  static List<Prospect> _orderByStreetThenSector(List<Prospect> pool) {
    if (pool.length <= 2) return List.of(pool);

    final byStreet = <String, List<Prospect>>{};
    for (final p in pool) {
      final k = _streetKey(p.address);
      (byStreet[k] ??= <Prospect>[]).add(p);
    }

    // centroïde global pour trier les rues
    final c = _centroid(pool);
    final streetKeys = byStreet.keys.toList();
    streetKeys.sort((ka, kb) {
      final ca = _centroid(byStreet[ka]!);
      final cb = _centroid(byStreet[kb]!);
      final aa = math.atan2(ca.lat - c.lat, ca.lng - c.lng);
      final bb = math.atan2(cb.lat - c.lat, cb.lng - c.lng);
      return aa.compareTo(bb);
    });

    final out = <Prospect>[];
    for (final k in streetKeys) {
      final list = byStreet[k]!;
      list.sort((a, b) {
        final na = _houseNumber(a.address);
        final nb = _houseNumber(b.address);
        if (na != null && nb != null) return na.compareTo(nb);
        if (na != null) return -1;
        if (nb != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      out.addAll(list);
    }
    return out;
  }

  static _Centroid _centroid(List<Prospect> pts) {
    double lat = 0;
    double lng = 0;
    for (final p in pts) {
      lat += p.lat;
      lng += p.lng;
    }
    return _Centroid(lat / pts.length, lng / pts.length);
  }

  static int? _houseNumber(String address) {
    final first = address.split(',').first.trim();
    final m = RegExp(r'^\s*(\d{1,5})\b').firstMatch(first);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static String _streetKey(String address) {
    final first = address.split(',').first.trim().toLowerCase();
    // enlève le numéro
    var s = first.replaceFirst(RegExp(r'^\s*\d{1,5}\s+'), '');
    // normalise les espaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // supprime des trucs trop génériques
    if (s.isEmpty) return 'inconnue';
    return s;
  }
}

class _Centroid {
  final double lat;
  final double lng;
  const _Centroid(this.lat, this.lng);
}

class _ClusterWrap {
  final double angle;
  final List<Prospect> items;
  _ClusterWrap({required this.angle, required this.items});
}

class _StreetPoint {
  final String key;
  final double lat;
  final double lng;
  final List<Prospect> items;
  _StreetPoint(this.key, this.lat, this.lng, this.items);
}
