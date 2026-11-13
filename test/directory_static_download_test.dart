import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_platform_io.dart';
import 'directory_install_test.dart' show ValidatedFactory;

class Headers extends Fake implements HttpHeaders {
  final String? location;
  Headers(this.location);
  @override
  String? value(String name) =>
      name == HttpHeaders.locationHeader ? location : null;
}

class Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  final List<int> data;
  @override
  final HttpHeaders headers;
  Response(this.statusCode, this.data, [String? location])
      : headers = Headers(location);
  @override
  int get contentLength => data.length;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(data).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request extends Fake implements HttpClientRequest {
  final Response response;
  Request(this.response);
  @override
  Future<HttpClientResponse> close() async => response;
  @override
  set followRedirects(bool value) {
    expect(value, isFalse);
  }
}

class Client extends Fake implements HttpClient {
  final List<Uri> requests = [];
  final Response Function(Uri) respond;
  Client(this.respond);
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    requests.add(uri);
    return Request(respond(uri));
  }

  @override
  void close({bool force = false}) {}
  @override
  set autoUncompress(bool value) {
    expect(value, isFalse);
  }

  @override
  set connectionTimeout(Duration? value) {}
}

void main() {
  late Directory support;
  late DirectoryPack pack;
  late List<int> bytes;
  setUp(() async {
    support =
        await Directory.systemTemp.createTemp('prospecto-static-download-');
    final catalog = jsonDecode(
            File('assets/directory_sample/catalog.json').readAsStringSync())
        as Map<String, dynamic>;
    final data =
        Map<String, dynamic>.from((catalog['packs'] as List).first as Map);
    bytes = File('assets/directory_sample/${data['url']}').readAsBytesSync();
    data['url'] =
        'https://github.com/example/packs/releases/download/v1/paris.sqlite.gz';
    pack = DirectoryPack(data);
  });
  tearDown(() async => support.delete(recursive: true));

  test('HTTPS release redirect installs exact verified gzip bytes', () async {
    final client = Client((uri) => uri.host == 'github.com'
        ? Response(302, [],
            'https://release-assets.githubusercontent.com/pack?signature=temporary')
        : Response(200, bytes));
    final backend = NativeDirectoryBackend(
        supportDirectory: () async => support,
        factory: ValidatedFactory()..pack = pack,
        httpClient: () => client);
    await backend.install(pack);
    expect(client.requests.map((u) => u.host),
        ['github.com', 'release-assets.githubusercontent.com']);
    expect((await backend.installed()).single.sqliteHash, pack.sqliteHash);
  });

  test(
      'HTTP downgrade, credentials, cycles and missing location never install a pack',
      () async {
    for (final location in [
      'http://files.example/pack',
      'https://user:secret@files.example/pack',
      pack.url.toString(),
      null
    ]) {
      final client = Client((_) => Response(302, [], location));
      final backend = NativeDirectoryBackend(
          supportDirectory: () async => support,
          factory: ValidatedFactory()..pack = pack,
          httpClient: () => client);
      await expectLater(
          backend.install(pack), throwsA(isA<DirectoryException>()));
      expect(client.requests, hasLength(1));
      expect(await backend.installed(), isEmpty);
    }
  });

  test('an endless redirect chain is bounded', () async {
    var redirects = 0;
    final client = Client(
        (_) => Response(302, [], 'https://files.example/next${redirects++}'));
    final backend = NativeDirectoryBackend(
        supportDirectory: () async => support,
        factory: ValidatedFactory()..pack = pack,
        httpClient: () => client);
    await expectLater(backend.install(pack), throwsException);
    expect(client.requests, hasLength(6));
    expect(await backend.installed(), isEmpty);
  });

  test('a redirect cannot bypass the archive checksum or announced length',
      () async {
    for (final body in [
      List<int>.filled(bytes.length, 0),
      bytes.sublist(0, bytes.length - 1),
      [...bytes, 0]
    ]) {
      final client = Client((uri) => uri.host == 'github.com'
          ? Response(307, [], 'https://files.example/pack')
          : Response(200, body));
      final backend = NativeDirectoryBackend(
          supportDirectory: () async => support,
          factory: ValidatedFactory()..pack = pack,
          httpClient: () => client);
      await expectLater(backend.install(pack), throwsException);
      expect(await backend.installed(), isEmpty);
    }
  });
}
