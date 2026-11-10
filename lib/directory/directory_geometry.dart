import 'dart:math' as math;

const _earthRadius = 6371008.8;
double directoryDistance(
  double lat,
  double lon,
  double otherLat,
  double otherLon,
) {
  final dlat = (otherLat - lat) * math.pi / 180;
  final dlon = (otherLon - lon) * math.pi / 180;
  final a = math.pow(math.sin(dlat / 2), 2) +
      math.cos(lat * math.pi / 180) *
          math.cos(otherLat * math.pi / 180) *
          math.pow(math.sin(dlon / 2), 2);
  return 2 * _earthRadius * math.asin(math.sqrt(a.clamp(0, 1)));
}

/// A conservative extent filter saves opening unrelated department packs.
/// It never certifies coverage; holes and exact distance are checked elsewhere.
bool directoryMayIntersectCircle(
  Map<String, dynamic> geometry, double lat, double lon, int radius,
) {
  var minLat = double.infinity, maxLat = double.negativeInfinity;
  var minLon = double.infinity, maxLon = double.negativeInfinity;
  void visit(Object? value) {
    if (value is! List) return;
    if (value.length >= 2 && value[0] is num && value[1] is num) {
      final x = (value[0] as num).toDouble();
      final y = (value[1] as num).toDouble();
      if (!x.isFinite || !y.isFinite) return;
      minLon = math.min(minLon, x); maxLon = math.max(maxLon, x);
      minLat = math.min(minLat, y); maxLat = math.max(maxLat, y);
    } else {
      for (final child in value) { visit(child); }
    }
  }
  visit(geometry['coordinates']);
  if (!minLat.isFinite || maxLon - minLon > 180) return true;
  final dy = (radius + 2) / 110000;
  final extremeLat = math.min(89.0, lat.abs() + dy);
  final dx = dy / math.cos(extremeLat * math.pi / 180).abs().clamp(0.001, 1);
  return lat + dy >= minLat && lat - dy <= maxLat &&
      lon + dx >= minLon && lon - dx <= maxLon;
}

/// Conservative containment, including holes. The local longitude scale uses
/// the smallest cosine anywhere a point of the requested circle can reach.
/// Every path inside that latitude strip is at least its projected distance.
/// Consequently an edge with projected distance > radius cannot touch the
/// spherical circle. A small extra margin rejects boundary/numeric ambiguity.
bool directoryCoversCircle(
  Map<String, dynamic> geometry,
  double lat,
  double lon,
  int radius,
) {
  if (!lat.isFinite ||
      !lon.isFinite ||
      lat.abs() > 75 ||
      lon.abs() > 180 ||
      radius < 0 ||
      radius > 10000) return false;
  try {
    final type = geometry['type'];
    final polygons = type == 'Polygon'
        ? [geometry['coordinates']]
        : type == 'MultiPolygon'
            ? geometry['coordinates'] as List
            : const [];
    final limit = radius + 2.0;
    final stripLat = lat.abs() + limit / _earthRadius * 180 / math.pi;
    final scaleX =
        _earthRadius * math.cos(stripLat * math.pi / 180) * math.pi / 180;
    final scaleY = _earthRadius * math.pi / 180;
    for (final polygon in polygons) {
      final rings = polygon as List;
      if (rings.isEmpty) continue;
      var valid = true;
      for (var n = 0; n < rings.length; n++) {
        final ring = rings[n] as List;
        if (ring.length < 4) {
          valid = false;
          break;
        }
        final first = ring.first as List;
        final last = ring.last as List;
        if (first[0] != last[0] || first[1] != last[1]) {
          valid = false;
          break;
        }
        var inside = false;
        for (var i = 1; i < ring.length; i++) {
          final a = ring[i - 1] as List;
          final b = ring[i] as List;
          final ax = (a[0] as num).toDouble(), ay = (a[1] as num).toDouble();
          final bx = (b[0] as num).toDouble(), by = (b[1] as num).toDouble();
          if (![ax, ay, bx, by].every((v) => v.isFinite) ||
              ax.abs() > 180 ||
              bx.abs() > 180 ||
              ay.abs() > 90 ||
              by.abs() > 90 ||
              (ax - lon).abs() > 180 ||
              (bx - lon).abs() > 180) {
            valid = false;
            break;
          }
          if ((ay > lat) != (by > lat) &&
              lon < (bx - ax) * (lat - ay) / (by - ay) + ax) inside = !inside;
          final x1 = (ax - lon) * scaleX, y1 = (ay - lat) * scaleY;
          final dx = (bx - ax) * scaleX, dy = (by - ay) * scaleY;
          final length2 = dx * dx + dy * dy;
          final t =
              length2 == 0 ? 0 : (-(x1 * dx + y1 * dy) / length2).clamp(0, 1);
          if (math.sqrt(math.pow(x1 + t * dx, 2) + math.pow(y1 + t * dy, 2)) <=
              limit) {
            valid = false;
            break;
          }
        }
        if (!valid || (n == 0 ? !inside : inside)) {
          valid = false;
          break;
        }
      }
      if (valid) return true;
    }
  } catch (_) {
    return false;
  }
  return false;
}
