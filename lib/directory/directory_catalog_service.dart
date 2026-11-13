import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'directory_models.dart';

typedef DirectoryCatalogFetch = Future<String> Function(Uri uri);

/// Static JSON and gzip files. No running directory API is required.
class DirectoryCatalogService {
  static const configuredUrl = String.fromEnvironment(
      'PROSPECTO_DIRECTORY_CATALOG_URL',
      defaultValue:
          'https://raw.githubusercontent.com/usasin/prospecto-directory-packs/main/current.json');
  final Uri url;
  final DirectoryCatalogFetch fetch;

  DirectoryCatalogService(String address, {required this.fetch})
      : url = checkedUri(address);

  static DirectoryCatalogService? configured(DirectoryCatalogFetch fetch) =>
      configuredUrl.trim().isEmpty
          ? null
          : DirectoryCatalogService(configuredUrl, fetch: fetch);

  static Uri checkedUri(String address) {
    final value = Uri.tryParse(address);
    if (value == null ||
        value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasFragment) {
      throw const DirectoryException(
          'Le catalogue doit utiliser un lien HTTPS.');
    }
    return value;
  }

  Future<List<DirectoryPack>> load() async {
    var current = url;
    String? expectedHash;
    final visited = <Uri>{};
    for (var depth = 0; depth < 3; depth++) {
      if (!visited.add(current)) {
        throw const DirectoryException(
            'Le lien du catalogue tourne en boucle.');
      }
      final content = await fetch(current);
      final bytes = utf8.encode(content);
      if (bytes.length > 4 * 1024 * 1024) {
        throw const DirectoryException(
            'Catalogue trop volumineux (4 Mo maximum).');
      }
      if (expectedHash != null &&
          sha256.convert(bytes).toString() != expectedHash) {
        throw const DirectoryException(
            'Catalogue mis à jour ou endommagé. Réessayez.');
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic> || decoded['schema_version'] != 1) {
        throw const DirectoryException(
            'Format du catalogue non pris en charge.');
      }
      if (decoded['packs'] is List) {
        if ((decoded['packs'] as List).length > 512) {
          throw const DirectoryException(
              'Trop de territoires dans ce catalogue.');
        }
        final packs = parseDirectoryCatalog(decoded, base: current);
        for (final pack in packs) {
          if (pack.demo || pack.url == null) {
            throw const DirectoryException(
                'Ce catalogue doit contenir des données publiques réelles.');
          }
          checkedUri(pack.url.toString());
          if (pack.json['schema_version'] != 1 ||
              pack.version != decoded['version']) {
            throw const DirectoryException(
                'Version de territoire incohérente.');
          }
        }
        return packs;
      }
      final next = decoded['catalog'];
      if (next is! String || next.isEmpty) {
        throw const DirectoryException('Liste des territoires absente.');
      }
      final hash = decoded['catalog_sha256'];
      if (hash != null &&
          (hash is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash))) {
        throw const DirectoryException('Empreinte du catalogue invalide.');
      }
      expectedHash = hash as String?;
      current = checkedUri(current.resolve(next).toString());
    }
    throw const DirectoryException('Le lien du catalogue est trop indirect.');
  }
}
