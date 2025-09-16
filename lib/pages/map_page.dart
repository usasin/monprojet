import 'dart:math' as math;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_background.dart';

class MapPage extends StatefulWidget {
  static const routeName = '/map';
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  DateTime _date = DateTime.now();
  Set<Marker> _markers = {};
  GoogleMapController? _ctrl;

  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _loadRoute();
  }

  @override
  void dispose() {
    _animController.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final newMarkers = <Marker>{};

    // 1) Position utilisateur
    try {
      final loc = Location();
      if (!(await loc.serviceEnabled())) await loc.requestService();
      final perm = await loc.requestPermission();
      if (perm == PermissionStatus.granted || perm == PermissionStatus.grantedLimited) {
        final u = await loc.getLocation();
        if (u.latitude != null && u.longitude != null) {
          newMarkers.add(Marker(
            markerId: const MarkerId('user'),
            position: LatLng(u.latitude!, u.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: 'Vous êtes ici'.tr()),
          ));
        }
      }
    } catch (_) {}

    // 2) Points prospects
    final ids = await FirestoreService().loadPlan(_date);
    if (ids.isNotEmpty) {
      final snaps = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('prospects')
          .where(FieldPath.documentId, whereIn: ids)
          .get();

      final docs = {for (var d in snaps.docs) d.id: d.data()};
      for (final id in ids) {
        final d = docs[id];
        if (d == null) continue;
        newMarkers.add(Marker(
          markerId: MarkerId(id),
          position: LatLng((d['lat'] as num).toDouble(), (d['lng'] as num).toDouble()),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
          infoWindow: InfoWindow(title: d['name'] as String?, snippet: d['address'] as String?),
        ));
      }
    }

    setState(() => _markers = newMarkers);

    // 3) Ajuste la caméra
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
  }

  void _fitToBounds() {
    if (_ctrl == null || _markers.isEmpty) return;

    // S'il n'y a qu'un point
    if (_markers.length == 1) {
      _ctrl!.animateCamera(CameraUpdate.newLatLngZoom(_markers.first.position, 13));
      return;
    }

    double? minLat, maxLat, minLng, maxLng;
    for (final m in _markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      minLat = (minLat == null) ? lat : math.min(minLat, lat);
      maxLat = (maxLat == null) ? lat : math.max(maxLat, lat);
      minLng = (minLng == null) ? lng : math.min(minLng, lng);
      maxLng = (maxLng == null) ? lng : math.max(maxLng, lng);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
    _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      setState(() => _date = d);
      await _loadRoute();
    }
  }

  Future<void> _shareRoute() async {
    final ids = await FirestoreService().loadPlan(_date);
    if (ids.isEmpty) return;

    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('prospects')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    final docs = {for (var d in snaps.docs) d.id: d.data()};

    final coords = ids.map((id) => '${docs[id]?['lat']},${docs[id]?['lng']}').join('/');
    final url = 'https://www.google.com/maps/dir/$coords';

    await Share.share(
      'Tournée du {date}'.tr(namedArgs: {'date': DateFormat.yMd().format(_date)}) + '\n$url',
      subject: 'Itinéraire {date}'.tr(namedArgs: {'date': DateFormat.yMd().format(_date)}),
    );
  }

  Future<void> _openInMaps() async {
    final ids = await FirestoreService().loadPlan(_date);
    if (ids.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucun point dans la tournée.'.tr())),
      );
      return;
    }

    final snaps = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('prospects')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    final docs = {for (var d in snaps.docs) d.id: d.data()};

    String? origin;
    try {
      final loc = Location();
      if (!(await loc.serviceEnabled())) await loc.requestService();
      final perm = await loc.requestPermission();
      if (perm == PermissionStatus.granted || perm == PermissionStatus.grantedLimited) {
        final here = await loc.getLocation();
        origin = '${here.latitude},${here.longitude}';
      }
    } catch (_) {}

    final allPts = [
      for (final id in ids) '${docs[id]?['lat']},${docs[id]?['lng']}'
    ]..removeWhere((e) => e.isEmpty);

    if (allPts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coordonnées manquantes.'.tr())),
      );
      return;
    }

    final originStr = origin ?? allPts.first;
    final destinationStr = allPts.last;
    final waypointList = (origin == null ? allPts.sublist(1) : allPts)
        .sublist(0, math.max(0, math.min(23, allPts.length - 1)))
        .where((p) => p != destinationStr)
        .toList();
    final waypoints = waypointList.join('|');

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=$originStr'
          '&destination=$destinationStr'
          '${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}'
          '&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir Google Maps.'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs = theme.colorScheme;

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Itinéraire'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            centerTitle: true,
            actions: [
              IconButton.filledTonal(
                icon: const Icon(Icons.share),
                tooltip: 'Partager'.tr(),
                onPressed: _shareRoute,
              ),
            ],
          ),
          body: Column(
            children: [
              // Carte "date" en verre dépoli
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Card(
                  color: cs.surfaceContainerHighest.withOpacity(.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AutoSizeText(
                              '${'Carte du'.tr()} ${DateFormat.yMMMMd(context.locale.languageCode).format(_date)}',
                              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              minFontSize: 12,
                            ),
                          ),
                          Icon(Icons.edit_calendar_rounded, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Google Map (plein écran)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(43.2965, 5.3698), // Marseille par défaut
                      zoom: 12,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    onMapCreated: (c) {
                      _ctrl = c;
                      // Ajuste la vue dès que la carte est prête
                      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToBounds());
                    },
                  ),
                ),
              ),
            ],
          ),

          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bandeau info
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Text(
                  'Appuyez sur le bouton pour démarrer la navigation'.tr(),
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),

              // Bouton pulsant “Ouvrir Google Maps”
              ScaleTransition(
                scale: _pulseAnimation,
                child: FloatingActionButton.extended(
                  onPressed: _openInMaps,
                  tooltip: 'Ouvrir Google Maps'.tr(),
                  icon: const Icon(Icons.route_rounded),
                  label: Text('Démarrer'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
