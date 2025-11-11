// lib/services/api_keys.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Clés Google Maps (celles que tu m'as montrées)
const String _WEB_GOOGLE_MAPS_KEY     = 'AIzaSyA6BxVTOmWxDlX3UzaA6GFhIa-YbdCvbmo';
const String _ANDROID_GOOGLE_MAPS_KEY = 'AIzaSyBA3GpdMujbxxea9QzKYosJrtF1n6OAKX4';
const String _IOS_GOOGLE_MAPS_KEY     = 'AIzaSyCWE5qSeyBDrZIXWiNrt_-I4GAyQk20F6M';

/// Retourne la bonne clé Google Maps selon la plateforme.
String getGoogleMapsApiKey() {
  if (kIsWeb) {
    return _WEB_GOOGLE_MAPS_KEY;
  }
  if (Platform.isAndroid) {
    return _ANDROID_GOOGLE_MAPS_KEY;
  }
  if (Platform.isIOS) {
    return _IOS_GOOGLE_MAPS_KEY;
  }
  return '';
}
