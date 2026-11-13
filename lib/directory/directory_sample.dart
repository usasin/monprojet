import 'dart:convert';
import 'package:flutter/services.dart';
import 'directory_models.dart';

/// Explicit test coordinates let the existing radius/category search work
/// without a first network geocoding request. No device location is inferred.
class DirectorySearchSeed {
  final String address;
  final double lat;
  final double lon;
  final String query;
  const DirectorySearchSeed(this.address, this.lat, this.lon, this.query);
}

class DirectorySample {
  static const assetRoot = 'assets/directory_sample/';
  final List<DirectoryPack> packs;
  final DirectorySearchSeed seed;
  const DirectorySample(this.packs, this.seed);

  static Future<DirectorySample> load() async {
    final catalog =
        jsonDecode(await rootBundle.loadString('${assetRoot}catalog.json'))
            as Map<String, dynamic>;
    final zone =
        jsonDecode(await rootBundle.loadString('${assetRoot}test_zone.json'))
            as Map<String, dynamic>;
    final packs = parseDirectoryCatalog(catalog);
    if (packs.isEmpty || packs.any((p) => p.demo || p.complete)) {
      throw const DirectoryException(
          'L’extrait inclus doit rester réel et partiel.');
    }
    return DirectorySample(
        packs,
        DirectorySearchSeed(
          zone['address'] as String,
          (zone['lat'] as num).toDouble(),
          (zone['lon'] as num).toDouble(),
          zone['query'] as String? ?? '',
        ));
  }

  Future<void> install(DirectoryBackend backend) async {
    for (final pack in packs) {
      final name = pack.json['url'];
      if (name is! String ||
          !RegExp(r'^[a-zA-Z0-9._-]+\.sqlite\.gz$').hasMatch(name)) {
        throw const DirectoryException('Nom du pack inclus invalide.');
      }
      final data = await rootBundle.load('$assetRoot$name');
      await backend.install(pack,
          bytes:
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}
