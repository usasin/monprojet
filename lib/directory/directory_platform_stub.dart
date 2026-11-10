import 'directory_models.dart';

DirectoryBackend createDirectoryBackend() => _UnsupportedDirectory();

class _UnsupportedDirectory implements DirectoryBackend {
  @override
  bool get supported => false;
  @override
  Future<List<DirectoryPack>> installed() async => [];
  @override
  Future<void> install(DirectoryPack pack,
          {String? localFile, List<int>? bytes}) async =>
      throw const DirectoryException('Installation disponible sur Android.');
  @override
  Future<void> remove(String packId) async {}
  @override
  Future<bool> rollback(String packId) async => false;
  @override
  Future<String> fetchCatalog(Uri uri) async =>
      throw const DirectoryException('Catalogue disponible sur Android.');
  @override
  Future<List<DirectoryRecord>> query(
    DirectoryPack pack,
    double lat,
    double lon,
    int radius,
    List<String>? categories,
  ) async =>
      [];
}
