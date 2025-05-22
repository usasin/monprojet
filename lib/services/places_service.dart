// lib/services/places_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prospect.dart';
import 'api_keys.dart';

class PlacesService {
  /// Utilise la clé adaptée à la plateforme
  final String apiKey;

  /// Par défaut : clé adaptée à la plateforme
  PlacesService([String? apiKey]) : apiKey = apiKey ?? getGoogleMapsApiKey();


  /// Recherche par zone (Text Search)
  Future<List<Prospect>> searchByCategory({
    required String category,
    required String area,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      {
        'query': '$category in $area',
        'key': apiKey,
      },
    );
    return _decodeAndSort(await http.get(uri), category);
  }

  /// Recherche à proximité (Nearby Search)
  Future<List<Prospect>> nearbySearch({
    required double lat,
    required double lng,
    required String category,
    int radius = 1500,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/nearbysearch/json',
      {
        'location': '$lat,$lng',
        'radius': radius.toString(),
        'type': category,
        'key': apiKey,
      },
    );
    return _decodeAndSort(await http.get(uri), category);
  }

  /// Décode la réponse et trie par nom
  List<Prospect> _decodeAndSort(http.Response resp, String category) {
    final data = jsonDecode(resp.body);
    final status = data['status'] as String;
    if (status != 'OK') {
      throw 'Places API error: $status';
    }
    final list = (data['results'] as List).map((e) {
      return Prospect(
        id: e['place_id'],
        name: e['name'],
        address: e['vicinity'] ?? e['formatted_address'] ?? '',
        lat: (e['geometry']['location']['lat'] as num).toDouble(),
        lng: (e['geometry']['location']['lng'] as num).toDouble(),
        category: category,
      );
    }).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}