import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

String getGoogleMapsApiKey() {
  if (kIsWeb) {
    return 'AIzaSyA6BxVTOmWxDIX3UzaA6GFhIa-YbdCvbmo'; // Mets ici ta clé Google Maps WEB
  } else if (Platform.isAndroid) {
    return 'AIzaSyBA3GpdMujbxxea9QzKYosJrtF1n6OAKX4'; // Mets ici ta clé Android (actuelle)
  }
  // Tu peux rajouter iOS si besoin
  return '';
}
