import 'dart:io';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:geolocator/geolocator.dart';

class Permissions {
  /// Appel unique au lancement
  static Future<void> init() async {
    if (!Platform.isIOS) return;

    // 1) ATT (avant toute init pub)
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await Future.delayed(const Duration(milliseconds: 250));
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    // 2) Localisation (WhenInUse)
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      // L’utilisateur peut activer manuellement le service de localisation
      // Geolocator.openLocationSettings();
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
  }

  /// A appeler si tu as besoin d’être sûr que la permission est accordée
  static Future<bool> ensureLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  }
}
