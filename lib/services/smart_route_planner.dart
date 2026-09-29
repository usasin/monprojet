import 'dart:math' as math;

import '../models/prospect.dart';

class PlannerPoint {
  final double lat;
  final double lng;
  final String label;

  const PlannerPoint({required this.lat, required this.lng, required this.label});
}

class PlannerConstraints {
  final DateTime day;
  final PlannerPoint start;
  final int workStartMinutes;
  final int workEndMinutes;
  final int defaultVisitDurationMinutes;
  final int maxStops;
  final bool trafficAware;

  const PlannerConstraints({
    required this.day,
    required this.start,
    this.workStartMinutes = 8 * 60 + 30,
    this.workEndMinutes = 18 * 60,
    this.defaultVisitDurationMinutes = 30,
    this.maxStops = 12,
    this.trafficAware = true,
  });

  DateTime atMinute(int minute) => DateTime(
        day.year,
        day.month,
        day.day,
        minute ~/ 60,
        minute % 60,
      );
}

class PlannedStop {
  final Prospect prospect;
  final DateTime arrival;
  final DateTime startVisit;
  final DateTime departure;
  final Duration travelDuration;
  final int distanceMeters;
  final String? warning;

  const PlannedStop({
    required this.prospect,
    required this.arrival,
    required this.startVisit,
    required this.departure,
    required this.travelDuration,
    required this.distanceMeters,
    this.warning,
  });
}

class SmartRouteResult {
  final List<PlannedStop> stops;
  final List<Prospect> unscheduled;
  final Duration totalTravel;
  final int totalDistanceMeters;
  final bool usedLiveTraffic;
  final String? fallbackReason;

  const SmartRouteResult({
    required this.stops,
    required this.unscheduled,
    required this.totalTravel,
    required this.totalDistanceMeters,
    required this.usedLiveTraffic,
    this.fallbackReason,
  });
}

class _MatrixCell {
  final int distanceMeters;
  final int durationSeconds;
  const _MatrixCell(this.distanceMeters, this.durationSeconds);
}

class _Window {
  final int openMinute;
  final int closeMinute;
  const _Window(this.openMinute, this.closeMinute);
}

/// Planificateur terrain 100 % gratuit : rendez-vous fixes, horaires
/// d'ouverture, durée de visite, priorité et heure de fin. Les distances sont
/// estimées localement à partir des coordonnées GPS, sans API payante ni clé
/// serveur. Une marge de circulation optionnelle rend les durées plus prudentes.
class SmartRoutePlanner {
  const SmartRoutePlanner();

  Future<SmartRouteResult> build({
    required List<Prospect> prospects,
    required PlannerConstraints constraints,
  }) async {
    final valid = prospects
        .where((p) => p.lat.abs() > .000001 || p.lng.abs() > .000001)
        .toList();
    if (valid.isEmpty) {
      return SmartRouteResult(
        stops: const [],
        unscheduled: prospects,
        totalTravel: Duration.zero,
        totalDistanceMeters: 0,
        usedLiveTraffic: false,
        fallbackReason: 'Aucune coordonnée exploitable.',
      );
    }

    final points = <PlannerPoint>[
      constraints.start,
      ...valid.map((p) => PlannerPoint(lat: p.lat, lng: p.lng, label: p.name)),
    ];

    final matrix = _localMatrix(
      points,
      trafficAware: constraints.trafficAware,
    );
    const live = false;
    final fallbackReason = constraints.trafficAware
        ? 'Estimation locale gratuite avec marge de circulation.'
        : 'Estimation locale gratuite, sans trafic temps réel.';

    final remaining = <int>{for (var i = 0; i < valid.length; i++) i};
    final stops = <PlannedStop>[];
    var currentPointIndex = 0;
    var now = constraints.atMinute(constraints.workStartMinutes);
    final end = constraints.atMinute(constraints.workEndMinutes);
    var totalDistance = 0;
    var totalTravelSeconds = 0;

    while (remaining.isNotEmpty && stops.length < constraints.maxStops) {
      int? bestProspectIndex;
      DateTime? bestArrival;
      DateTime? bestStart;
      DateTime? bestDeparture;
      _MatrixCell? bestCell;
      double bestScore = -double.infinity;
      String? bestWarning;

      for (final prospectIndex in remaining) {
        final p = valid[prospectIndex];
        final cell = matrix[currentPointIndex][prospectIndex + 1];
        final arrival = now.add(Duration(seconds: cell.durationSeconds));
        final window = _openingWindow(p.openingHours, constraints.day.weekday);
        var startVisit = arrival;
        String? warning;

        if (window != null) {
          final opens = constraints.atMinute(window.openMinute);
          final closes = constraints.atMinute(window.closeMinute);
          if (startVisit.isBefore(opens)) startVisit = opens;
          if (!startVisit.isBefore(closes)) continue;
        }

        if (p.appointmentAt != null && _sameDay(p.appointmentAt!, constraints.day)) {
          final appointment = p.appointmentAt!;
          if (arrival.isAfter(appointment.add(const Duration(minutes: 15)))) {
            continue;
          }
          if (startVisit.isBefore(appointment)) startVisit = appointment;
          if (arrival.isAfter(appointment)) warning = 'Arrivée estimée après le rendez-vous';
        }

        final visitMinutes = p.visitDurationMinutes > 0
            ? p.visitDurationMinutes
            : constraints.defaultVisitDurationMinutes;
        final departure = startVisit.add(Duration(minutes: visitMinutes));
        if (departure.isAfter(end)) continue;

        final windowForClose = _openingWindow(p.openingHours, constraints.day.weekday);
        if (windowForClose != null &&
            departure.isAfter(constraints.atMinute(windowForClose.closeMinute))) {
          continue;
        }

        final waitMinutes = startVisit.difference(arrival).inMinutes.clamp(0, 240);
        final travelMinutes = cell.durationSeconds / 60;
        final appointmentBonus = p.appointmentAt != null ? 900.0 : 0.0;
        final followUpBonus = p.prochaineVisite != null &&
                _sameDay(p.prochaineVisite!, constraints.day)
            ? 250.0
            : 0.0;
        final score = p.priority * 180.0 +
            appointmentBonus +
            followUpBonus -
            travelMinutes * 4.0 -
            waitMinutes * 1.5;

        if (score > bestScore) {
          bestScore = score;
          bestProspectIndex = prospectIndex;
          bestArrival = arrival;
          bestStart = startVisit;
          bestDeparture = departure;
          bestCell = cell;
          bestWarning = warning;
        }
      }

      if (bestProspectIndex == null ||
          bestArrival == null ||
          bestStart == null ||
          bestDeparture == null ||
          bestCell == null) {
        break;
      }

      final chosen = valid[bestProspectIndex];
      stops.add(PlannedStop(
        prospect: chosen,
        arrival: bestArrival,
        startVisit: bestStart,
        departure: bestDeparture,
        travelDuration: Duration(seconds: bestCell.durationSeconds),
        distanceMeters: bestCell.distanceMeters,
        warning: bestWarning,
      ));
      totalDistance += bestCell.distanceMeters;
      totalTravelSeconds += bestCell.durationSeconds;
      now = bestDeparture;
      currentPointIndex = bestProspectIndex + 1;
      remaining.remove(bestProspectIndex);
    }

    final unscheduled = <Prospect>[
      ...remaining.map((i) => valid[i]),
      ...prospects.where((p) => !valid.contains(p)),
    ];

    return SmartRouteResult(
      stops: stops,
      unscheduled: unscheduled,
      totalTravel: Duration(seconds: totalTravelSeconds),
      totalDistanceMeters: totalDistance,
      usedLiveTraffic: live,
      fallbackReason: fallbackReason,
    );
  }

  List<List<_MatrixCell>> _localMatrix(
    List<PlannerPoint> points, {
    required bool trafficAware,
  }) {
    final factor = trafficAware ? 1.30 : 1.12;
    return List.generate(points.length, (i) {
      return List.generate(points.length, (j) {
        if (i == j) return const _MatrixCell(0, 0);
        final meters = _haversine(
          points[i].lat,
          points[i].lng,
          points[j].lat,
          points[j].lng,
        ).round();
        // Vitesse urbaine moyenne volontairement prudente : 28 km/h.
        final seconds = math.max(45, ((meters / 7.78) * factor).round());
        return _MatrixCell(meters, seconds);
      });
    });
  }

  _Window? _openingWindow(String? raw, int weekday) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();
    if (value.contains('24/7')) return const _Window(0, 24 * 60);

    const codes = {
      1: 'Mo',
      2: 'Tu',
      3: 'We',
      4: 'Th',
      5: 'Fr',
      6: 'Sa',
      7: 'Su',
    };
    final today = codes[weekday]!;
    for (final section in value.split(';')) {
      final part = section.trim();
      if (part.isEmpty || part.toLowerCase().contains('off')) continue;
      final pieces = part.split(RegExp(r'\s+'));
      if (pieces.length < 2) continue;
      final daySpec = pieces.first;
      if (!_dayMatches(daySpec, today)) continue;
      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})')
          .firstMatch(part);
      if (timeMatch == null) continue;
      final open = int.parse(timeMatch.group(1)!) * 60 + int.parse(timeMatch.group(2)!);
      final close = int.parse(timeMatch.group(3)!) * 60 + int.parse(timeMatch.group(4)!);
      if (close > open) return _Window(open, close);
    }
    return null;
  }

  bool _dayMatches(String spec, String today) {
    if (spec == today) return true;
    final range = RegExp(r'^(Mo|Tu|We|Th|Fr|Sa|Su)-(Mo|Tu|We|Th|Fr|Sa|Su)$')
        .firstMatch(spec);
    if (range == null) return spec.split(',').contains(today);
    const order = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final start = order.indexOf(range.group(1)!);
    final end = order.indexOf(range.group(2)!);
    final target = order.indexOf(today);
    return start <= end
        ? target >= start && target <= end
        : target >= start || target <= end;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
