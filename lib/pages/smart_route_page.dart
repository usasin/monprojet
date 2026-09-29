import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';

import '../models/prospect.dart';
import '../services/osm_search_service.dart';
import '../services/smart_route_planner.dart';


class SmartRouteSelection {
  final List<String> orderedIds;
  final Map<String, dynamic> metadata;

  const SmartRouteSelection({
    required this.orderedIds,
    required this.metadata,
  });
}

class SmartRoutePage extends StatefulWidget {
  final List<Prospect> prospects;
  final DateTime date;

  const SmartRoutePage({
    super.key,
    required this.prospects,
    required this.date,
  });

  @override
  State<SmartRoutePage> createState() => _SmartRoutePageState();
}

class _SmartRoutePageState extends State<SmartRoutePage> {
  final _addressCtrl = TextEditingController();
  final _osm = OSMSearchService();
  final _planner = SmartRoutePlanner();

  PlannerPoint? _start;
  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _workEnd = const TimeOfDay(hour: 18, minute: 0);
  int _visitDuration = 30;
  int _maxStops = 12;
  bool _trafficAware = true;
  bool _busy = false;
  SmartRouteResult? _result;
  String? _error;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final location = Location();
      var enabled = await location.serviceEnabled();
      if (!enabled) enabled = await location.requestService();
      if (!enabled) throw Exception('Activez la localisation du téléphone.');

      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        throw Exception('Autorisation de localisation refusée.');
      }

      final data = await location.getLocation();
      final lat = data.latitude;
      final lng = data.longitude;
      if (lat == null || lng == null) throw Exception('Position introuvable.');
      setState(() {
        _start = PlannerPoint(lat: lat, lng: lng, label: 'Position actuelle');
        _addressCtrl.text = 'Position actuelle';
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _geocodeAddress() async {
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Saisissez une adresse de départ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final point = await _osm.geocode(
        address,
        languageCode: context.locale.languageCode,
      );
      setState(() => _start = PlannerPoint(
            lat: point.lat,
            lng: point.lng,
            label: address,
          ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _workStart : _workEnd,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _workStart = picked;
      } else {
        _workEnd = picked;
      }
    });
  }

  Future<void> _optimize() async {
    if (_start == null) await _geocodeAddress();
    if (_start == null || !mounted) return;
    final startMinutes = _workStart.hour * 60 + _workStart.minute;
    final endMinutes = _workEnd.hour * 60 + _workEnd.minute;
    if (endMinutes <= startMinutes + 30) {
      setState(() => _error = 'L’heure de fin doit être après l’heure de départ.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _planner.build(
        prospects: widget.prospects,
        constraints: PlannerConstraints(
          day: widget.date,
          start: _start!,
          workStartMinutes: startMinutes,
          workEndMinutes: endMinutes,
          defaultVisitDurationMinutes: _visitDuration,
          maxStops: _maxStops,
          trafficAware: _trafficAware,
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  SmartRouteSelection _selection(SmartRouteResult result) {
    final start = _start!;
    return SmartRouteSelection(
      orderedIds: result.stops.map((stop) => stop.prospect.id).toList(),
      metadata: <String, dynamic>{
        'version': 1,
        'generatedAt': DateTime.now(),
        'day': DateTime(widget.date.year, widget.date.month, widget.date.day),
        'start': <String, dynamic>{
          'label': start.label,
          'lat': start.lat,
          'lng': start.lng,
        },
        'workStartMinutes': _workStart.hour * 60 + _workStart.minute,
        'workEndMinutes': _workEnd.hour * 60 + _workEnd.minute,
        'defaultVisitDurationMinutes': _visitDuration,
        'maxStops': _maxStops,
        'trafficRequested': _trafficAware,
        'usedLiveTraffic': result.usedLiveTraffic,
        if (result.fallbackReason != null)
          'fallbackReason': result.fallbackReason,
        'totalDistanceMeters': result.totalDistanceMeters,
        'totalTravelSeconds': result.totalTravel.inSeconds,
        'unscheduledProspectIds':
            result.unscheduled.map((prospect) => prospect.id).toList(),
        'unscheduledProspects': result.unscheduled
            .map((prospect) => <String, dynamic>{
                  'id': prospect.id,
                  'name': prospect.name,
                  'address': prospect.address,
                })
            .toList(),
        'stops': result.stops
            .asMap()
            .entries
            .map((entry) {
              final stop = entry.value;
              return <String, dynamic>{
                'position': entry.key + 1,
                'prospectId': stop.prospect.id,
                'prospectName': stop.prospect.name,
                'address': stop.prospect.address,
                'arrival': stop.arrival,
                'startVisit': stop.startVisit,
                'departure': stop.departure,
                'travelSeconds': stop.travelDuration.inSeconds,
                'distanceMeters': stop.distanceMeters,
                'priority': stop.prospect.priority,
                'visitDurationMinutes': stop.prospect.visitDurationMinutes,
                if ((stop.prospect.openingHours?.trim().isNotEmpty ?? false))
                  'openingHours': stop.prospect.openingHours,
                if (stop.prospect.appointmentAt != null)
                  'appointmentAt': stop.prospect.appointmentAt,
                if (stop.warning != null) 'warning': stop.warning,
              };
            })
            .toList(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const LText('Tournée intelligente'),
        actions: [
          if (result != null && result.stops.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_selection(result)),
              icon: const Icon(Icons.check_rounded),
              label: const LText('Utiliser'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LText(
                      'Prospecto prépare automatiquement la tournée la plus efficace pour votre journée.',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Adresse de départ'.tr(),
                        prefixIcon: const Icon(Icons.trip_origin_rounded),
                        suffixIcon: IconButton(
                          tooltip: 'Géocoder l’adresse'.tr(),
                          onPressed: _busy ? null : _geocodeAddress,
                          icon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      onSubmitted: (_) => _geocodeAddress(),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const LText('Utiliser ma position actuelle'),
                    ),
                    if (_start != null) ...[
                      const SizedBox(height: 8),
                      LText(
                        'Départ validé : ${_start!.label}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Début',
                            value: _workStart,
                            onTap: () => _pickTime(start: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeTile(
                            label: 'Fin',
                            value: _workEnd,
                            onTap: () => _pickTime(start: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LText('Durée de visite par défaut : $_visitDuration min'),
                    Slider(
                      min: 15,
                      max: 90,
                      divisions: 5,
                      value: _visitDuration.toDouble(),
                      label: '$_visitDuration min',
                      onChanged: (v) => setState(() => _visitDuration = v.round()),
                    ),
                    LText('Nombre maximum de visites : $_maxStops'),
                    Slider(
                      min: 3,
                      max: 20,
                      divisions: 17,
                      value: _maxStops.toDouble(),
                      label: '$_maxStops',
                      onChanged: (v) => setState(() => _maxStops = v.round()),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const LText('Ajouter une marge de circulation'),
                      subtitle: const LText(
                        'Estimation locale gratuite avec des durées de trajet plus prudentes.',
                      ),
                      value: _trafficAware,
                      onChanged: (v) => setState(() => _trafficAware = v),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      LText(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _busy ? null : _optimize,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: LText(_busy ? 'Calcul en cours…' : 'Optimiser ma journée'),
                    ),
                  ],
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              _SummaryCard(result: result),
              const SizedBox(height: 12),
              ...result.stops.asMap().entries.map((entry) {
                final stop = entry.value;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: LText('${entry.key + 1}')),
                    title: LText(stop.prospect.name),
                    subtitle: LText(
                      '${DateFormat('HH:mm').format(stop.startVisit)} – '
                      '${DateFormat('HH:mm').format(stop.departure)}\n'
                      '${stop.prospect.address}\n'
                      '${(stop.distanceMeters / 1000).toStringAsFixed(1)} km · '
                      '${stop.travelDuration.inMinutes} min de route'
                      '${stop.warning == null ? '' : '\n⚠ ${stop.warning}'}',
                    ),
                    isThreeLine: true,
                    trailing: _PriorityBadge(stop.prospect.priority),
                  ),
                );
              }),
              if (result.unscheduled.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: LText(
                      '${result.unscheduled.length} prospect(s) non planifié(s) : '
                      'horaires, rendez-vous, capacité ou distance incompatibles.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: result.stops.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_selection(result)),
                icon: const Icon(Icons.check_circle_rounded),
                label: const LText('Utiliser cet ordre dans ma tournée'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  const _TimeTile({required this.label, required this.value, required this.onTap});



  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: LText(value.format(context), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final SmartRouteResult result;
  const _SummaryCard({required this.result});



  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '${result.stops.length} visites · '
              '${(result.totalDistanceMeters / 1000).toStringAsFixed(1)} km · '
              '${result.totalTravel.inMinutes} min de route',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            LText(result.usedLiveTraffic
                ? 'Estimation locale gratuite.'
                : (result.fallbackReason ?? 'Estimation locale gratuite.')),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final int value;
  const _PriorityBadge(this.value);



  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: LText('P$value'),
      avatar: const Icon(Icons.flag_rounded, size: 16),
    );
  }
}
