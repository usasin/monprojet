import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';

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
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadRoute();

    _animController = AnimationController(
      vsync: this, // <-- ici "this" doit être un TickerProvider, donc le mixin est obligatoire
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadRoute() async {
    _markers.clear();

    // 1) Position utilisateur
    final loc = Location();
    if (!(await loc.serviceEnabled())) await loc.requestService();
    if (await loc.requestPermission() == PermissionStatus.granted) {
      final u = await loc.getLocation();
      _markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(u.latitude!, u.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: 'Vous êtes ici'.tr()),
      ));
    }

    // 2) Points prospects
    final ids = await FirestoreService().loadPlan(_date);
    if (ids.isEmpty) {
      setState(() {});
      return;
    }

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
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: LatLng(d['lat'], d['lng']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: d['name'], snippet: d['address']),
      ));
    }

    setState(() {});
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
      if (_markers.isNotEmpty) {
        _ctrl?.animateCamera(
          CameraUpdate.newLatLngZoom(_markers.first.position, 13),
        );
      }
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

    final coords = ids
        .map((id) => '${docs[id]?['lat']},${docs[id]?['lng']}')
        .join('/');
    final url = 'https://www.google.com/maps/dir/$coords';

    await Share.share(
      'Tournée du {date}'.tr(
          namedArgs: {'date': DateFormat.yMd().format(_date)}) + '\n$url',
      subject: 'Itinéraire {date}'.tr(
          namedArgs: {'date': DateFormat.yMd().format(_date)}),
    );
  }

  Future<void> _openInMaps() async {
    final ids = await FirestoreService().loadPlan(_date);
    if (ids.isEmpty) {
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
      if (await loc.requestPermission() == PermissionStatus.granted) {
        final here = await loc.getLocation();
        origin = '${here.latitude},${here.longitude}';
      }
    } catch (_) {}

    final allPts = [
      for (final id in ids) '${docs[id]?['lat']},${docs[id]?['lng']}'
    ]
      ..removeWhere((e) => e.isEmpty);

    if (allPts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coordonnées manquantes.'.tr())),
      );
      return;
    }

    final originStr = origin ?? allPts.first;
    final destinationStr = allPts.last;
    final waypoints = (origin == null ? allPts.sublist(1) : allPts)
        .sublist(0, max(0, min(23, allPts.length - 1)))
        .where((p) => p != destinationStr)
        .join('|');

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ouvrir Google Maps.'.tr())),
      );
    }
  }
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
  // ... tout le code précédent reste inchangé

  @override
  Widget build(BuildContext context) {
    final theme = context
        .watch<ThemeProvider>()
        .currentTheme;
    final cs = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          title: Text('Itinéraire'.tr()),
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
            // Carte de sélection de date + bouton ouvrir Maps
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AutoSizeText(
                            '${'Carte du'.tr()} ${DateFormat.yMMMMd(
                                context.locale.languageCode).format(_date)}',
                            style: TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            minFontSize: 12,
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),

            // La carte Google
            Expanded(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(43.2965, 5.3698),
                  zoom: 12,
                ),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                onMapCreated: (c) => _ctrl = c,
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
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
            ScaleTransition(
              scale: _pulseAnimation,
              child: FloatingActionButton(
                onPressed: _openInMaps,
                tooltip: 'Ouvrir Google Maps'.tr(),
                elevation: 10,
                backgroundColor: cs.primary,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.7),
                        spreadRadius: 8,
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons/carte.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.map_outlined, size: 28, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
