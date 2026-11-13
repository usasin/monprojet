import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_geometry.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_service.dart';
import 'package:ai_prospect_gps/services/osm_search_service.dart';

Map<String, dynamic> square({bool hole = false}) => {
      'type': 'Polygon',
      'coordinates': [
        [
          [1, 47],
          [3, 47],
          [3, 49],
          [1, 49],
          [1, 47],
        ],
        if (hole)
          [
            [1.99, 47.99],
            [2.01, 47.99],
            [2.01, 48.01],
            [1.99, 48.01],
            [1.99, 47.99],
          ],
      ],
    };
DirectoryPack pack({
  String id = 'fr-75',
  bool complete = true,
  bool demo = false,
  Map<String, dynamic>? geometry,
}) =>
    DirectoryPack({
      'pack_id': id,
      'version': '2026-10-28',
      'department': '75',
      'data_date': '2026-10-28',
      'coverage_complete': complete,
      'is_demo': demo,
      'coverage_geojson': geometry ?? square(),
      'gzip_sha256': List.filled(64, 'a').join(),
      'sqlite_sha256': List.filled(64, 'b').join(),
      'gzip_size_bytes': 100,
      'sqlite_size_bytes': 200,
    });

OSMPlace place({
  String id = 'siret:12345678901234',
  String name = 'Hôtel de Paris',
  double lat = 48,
  double lon = 2,
}) =>
    OSMPlace(
      id: id,
      name: name,
      address: '1 rue du Test, Paris',
      lat: lat,
      lng: lon,
      category: 'Hôtel',
    );

DirectoryRecord record(DirectoryPack source, {OSMPlace? establishment}) {
  final value = establishment ?? place();
  return DirectoryRecord(
      value, {'id': value.id, 'name': value.name}, [], source);
}

final categories = DirectoryCategories({
  'schema_version': 1,
  'categories': [
    {
      'id': 'hotel',
      'label': 'Hôtel',
      'synonyms': ['hotels', 'hébergement'],
    },
    {
      'id': 'restaurant',
      'label': 'Restaurant',
      'synonyms': ['restaurants'],
    },
  ],
});

class MemoryBackend implements DirectoryBackend {
  @override
  bool supported = true;
  List<DirectoryPack> packs;
  Object? error;
  int queries = 0;
  final List<String> queriedPacks = [];
  final Map<String, List<DirectoryRecord>> rows;
  List<String>? requestedCategories;
  MemoryBackend(this.packs, {Map<String, List<DirectoryRecord>>? rows})
      : rows = rows ?? {};
  @override
  Future<List<DirectoryPack>> installed() async => packs;
  @override
  Future<List<DirectoryRecord>> query(
    DirectoryPack pack,
    double lat,
    double lon,
    int radius,
    List<String>? categories,
  ) async {
    queries++;
    queriedPacks.add(pack.id);
    requestedCategories = categories;
    if (error != null) throw error!;
    return rows[pack.id] ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Circle coverage, boundaries and holes', () {
    test(
      'complete circle inside outer polygon',
      () => expect(directoryCoversCircle(square(), 48, 2, 10000), isTrue),
    );
    test('outside, tangent and crossing circles are rejected', () {
      expect(directoryCoversCircle(square(), 46, 2, 1000), isFalse);
      expect(directoryCoversCircle(square(), 47, 2, 1000), isFalse);
      expect(directoryCoversCircle(square(), 47.005, 2, 1000), isFalse);
    });
    test('holes and concavities are not treated as bounding boxes', () {
      expect(directoryCoversCircle(square(hole: true), 48, 2, 500), isFalse);
      expect(
        directoryCoversCircle(square(hole: true), 48, 2.02, 1000),
        isFalse,
      );
      final concave = {
        'type': 'Polygon',
        'coordinates': [
          [
            [1, 47],
            [3, 47],
            [3, 49],
            [2.1, 49],
            [2.1, 47.9],
            [1.9, 47.9],
            [1.9, 49],
            [1, 49],
            [1, 47],
          ],
        ],
      };
      expect(directoryCoversCircle(concave, 48, 2, 500), isFalse);
    });
    test(
      'multipolygon selects the containing island',
      () => expect(
        directoryCoversCircle(
          {
            'type': 'MultiPolygon',
            'coordinates': [square()['coordinates']],
          },
          48,
          2,
          1000,
        ),
        isTrue,
      ),
    );
    test('invalid and unsupported geometry never claims coverage', () {
      expect(
        directoryCoversCircle(
          {
            'type': 'Point',
            'coordinates': [2, 48],
          },
          48,
          2,
          100,
        ),
        isFalse,
      );
      expect(directoryCoversCircle(square(), double.nan, 2, 1000), isFalse);
    });
  });
  test(
    'one category source resolves accents, synonyms, unions and unsupported text',
    () {
      expect(categories.resolve('HÔTEL'), ['hotel']);
      expect(categories.resolve('hébergement, restaurants'), [
        'hotel',
        'restaurant',
      ]);
      expect(categories.resolve('hotel, catégorie inconnue'), isEmpty);
      expect(categories.resolve(''), isNull);
    },
  );
  test(
    'covered empty local search is authoritative, without network',
    () async {
      final backend = MemoryBackend([pack()]);
      final service = DirectoryService(
        backend: backend,
        categories: () async => categories,
      );
      final result = await service.search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'hotel',
        fallback: () async => throw StateError('must stay local'),
      );
      expect(result.local, isTrue);
      expect(result.partial, isFalse);
      expect(result.networkUnavailable, isFalse);
      expect(result.places, isEmpty);
      expect(backend.queries, 1);
      expect(backend.requestedCategories, ['hotel']);
    },
  );
  test(
    'absent packs fall back exactly once without claiming local coverage',
    () async {
      final backend = MemoryBackend([]);
      var count = 0;
      final result = await DirectoryService(
        backend: backend,
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'hotel',
        fallback: () async {
          count++;
          return [];
        },
      );
      expect(result.local, isFalse);
      expect(result.partial, isTrue);
      expect(result.networkUnavailable, isFalse);
      expect(count, 1);
      expect(backend.queries, 0);
    },
  );
  test(
    'incomplete and crossing complete packs are queried with one online fallback',
    () async {
      for (final source in [
        pack(complete: false),
        pack(geometry: square(hole: true)),
      ]) {
        final row = record(source);
        final backend = MemoryBackend([
          source
        ], rows: {
          source.id: [row]
        });
        var count = 0;
        final result = await DirectoryService(
          backend: backend,
          categories: () async => categories,
        ).search(
          lat: 48,
          lon: 2,
          radius: 1000,
          query: 'hotel',
          fallback: () async {
            count++;
            return [];
          },
        );
        expect(result.places.map((p) => p.id), [row.place.id]);
        expect(result.details[row.place.id], same(row));
        expect(result.local, isFalse);
        expect(result.partial, isTrue);
        expect(result.networkUnavailable, isFalse);
        expect(count, 1);
        expect(backend.queries, 1);
        expect(backend.requestedCategories, ['hotel']);
      }
    },
  );
  test(
    'unsupported category uses online fallback without querying local rows',
    () async {
      final backend = MemoryBackend([pack()]);
      var count = 0;
      final result = await DirectoryService(
        backend: backend,
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'unknown',
        fallback: () async {
          count++;
          return [];
        },
      );
      expect(result.local, isFalse);
      expect(result.partial, isTrue);
      expect(count, 1);
      expect(backend.queries, 0);
    },
  );
  test(
    'partial local rows remain usable when the online fallback fails',
    () async {
      final source = pack(complete: false);
      final row = record(source);
      final backend = MemoryBackend([
        source
      ], rows: {
        source.id: [row]
      });
      var count = 0;
      final result = await DirectoryService(
        backend: backend,
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'hotel',
        fallback: () async {
          count++;
          throw StateError('network offline');
        },
      );
      expect(result.places.map((p) => p.id), [row.place.id]);
      expect(result.details[row.place.id], same(row));
      expect(result.local, isTrue);
      expect(result.partial, isTrue);
      expect(result.networkUnavailable, isTrue);
      expect(result.notice, isNotEmpty);
      expect(count, 1);
      expect(backend.queries, 1);
    },
  );
  test(
    'empty partial rows and online failure are an error, never no results',
    () async {
      for (final sources in [
        <DirectoryPack>[],
        [pack(complete: false)]
      ]) {
        final backend = MemoryBackend(sources);
        var count = 0;
        await expectLater(
          DirectoryService(
            backend: backend,
            categories: () async => categories,
          ).search(
            lat: 48,
            lon: 2,
            radius: 1000,
            query: 'hotel',
            fallback: () async {
              count++;
              throw StateError('network offline');
            },
          ),
          throwsA(isA<DirectoryException>()),
        );
        expect(count, 1);
        expect(backend.queries, sources.length);
      }
    },
  );
  test(
    'local and online matches keep the online id and alias local details',
    () async {
      final source = pack(complete: false);
      final local = record(source);
      final online = place(
        id: 'osm:node:42',
        name: 'HÔTEL DE PARIS',
        lat: 48.0001,
      );
      expect(directoryDistance(48, 2, online.lat, online.lng), lessThan(35));
      var count = 0;
      final result = await DirectoryService(
        backend: MemoryBackend([
          source
        ], rows: {
          source.id: [local]
        }),
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'hotel',
        fallback: () async {
          count++;
          return [online];
        },
      );
      expect(result.places.map((p) => p.id), [online.id]);
      expect(result.details[online.id], same(local));
      expect(result.details[local.place.id], same(local));
      expect(result.local, isFalse);
      expect(result.partial, isTrue);
      expect(count, 1);
    },
  );
  test(
    'same id is merged even when names or locations differ',
    () async {
      final source = pack(complete: false);
      final local = record(source);
      final online =
          place(id: local.place.id, name: 'New legal name', lat: 48.01);
      final result = await DirectoryService(
        backend: MemoryBackend([
          source
        ], rows: {
          source.id: [local]
        }),
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: '',
        fallback: () async => [online],
      );
      expect(result.places, hasLength(1));
      expect(result.places.single.id, online.id);
      expect(result.details[online.id], same(local));
    },
  );
  test(
    'different nearby names and same names beyond 35m remain separate',
    () async {
      final source = pack(complete: false);
      final local = record(source);
      final differentName = place(id: 'osm:1', name: 'Hôtel du Centre');
      final farSameName = place(id: 'osm:2', lat: 48.0005);
      expect(directoryDistance(48, 2, farSameName.lat, farSameName.lng),
          greaterThan(35));
      final result = await DirectoryService(
        backend: MemoryBackend([
          source
        ], rows: {
          source.id: [local]
        }),
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: 'hotel',
        fallback: () async => [differentName, farSameName],
      );
      expect(
          result.places.map((p) => p.id),
          unorderedEquals([
            local.place.id,
            differentName.id,
            farSameName.id,
          ]));
    },
  );
  test(
    'several local packs deduplicate repeated establishment ids',
    () async {
      final department = pack(complete: false);
      final region = DirectoryPack({
        ...pack(id: 'fr-region-11', complete: false).json,
        'department': '',
        'partition': 'region',
        'region': '11',
      });
      final first = record(department);
      final second = record(region);
      final backend = MemoryBackend([
        department,
        region
      ], rows: {
        department.id: [first],
        region.id: [second],
      });
      var count = 0;
      final result = await DirectoryService(
        backend: backend,
        categories: () async => categories,
      ).search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: '',
        fallback: () async {
          count++;
          return [];
        },
      );
      expect(backend.queriedPacks, [department.id, region.id]);
      expect(result.places.map((p) => p.id), [first.place.id]);
      expect(result.details[first.place.id], isNotNull);
      expect(result.partial, isTrue);
      expect(count, 1);
    },
  );
  test(
    'demo is blocked until explicit activation and always labelled',
    () async {
      final backend = MemoryBackend([pack(demo: true)]);
      final service = DirectoryService(
        backend: backend,
        categories: () async => categories,
      );
      expect(
        (await service.search(
          lat: 48,
          lon: 2,
          radius: 1000,
          query: '',
          fallback: () async => [],
        ))
            .local,
        isFalse,
      );
      service.allowDemo = true;
      final result = await service.search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: '',
        fallback: () async => throw StateError('local'),
      );
      expect(result.local, isTrue);
      expect(result.notice, contains('DÉMONSTRATION'));
    },
  );
  test(
    'corruption falls back with explicit warning and never becomes local zero',
    () async {
      final backend = MemoryBackend([pack()])
        ..error = const DirectoryException('SHA-256 incorrect');
      var fallbackCount = 0;
      final service = DirectoryService(
        backend: backend,
        categories: () async => categories,
      );
      final result = await service.search(
        lat: 48,
        lon: 2,
        radius: 1000,
        query: '',
        fallback: () async {
          fallbackCount++;
          return [];
        },
      );
      expect(result.local, isFalse);
      expect(result.notice, contains('endommagé'));
      expect(fallbackCount, 1);
      await expectLater(
        service.search(
          lat: 48,
          lon: 2,
          radius: 1000,
          query: '',
          fallback: () async => throw StateError('offline'),
        ),
        throwsA(isA<DirectoryException>()),
      );
    },
  );
  test(
    'ordinary network failure is explicit and does not retry',
    () async {
      var count = 0;
      await expectLater(
        DirectoryService(
          backend: MemoryBackend([]),
          categories: () async => categories,
        ).search(
          lat: 48,
          lon: 2,
          radius: 1000,
          query: '',
          fallback: () async {
            count++;
            throw StateError('network');
          },
        ),
        throwsA(isA<DirectoryException>()),
      );
      expect(count, 1);
    },
  );
  test(
      'regional catalogs allow an empty department only with an explicit region',
      () {
    final regional = {
      ...pack(id: 'fr-region-11').json,
      'department': '',
      'partition': 'region',
      'region': '11',
    };
    final parsed = parseDirectoryCatalog({
      'schema_version': 1,
      'packs': [pack().json, regional],
    });
    expect(parsed.map((p) => p.id), ['fr-75', 'fr-region-11']);
    expect(parsed.last.department, isEmpty);
    for (final invalid in [
      {...regional, 'region': ''},
      {...regional, 'partition': 'department'},
      {...regional, 'partition': null},
    ]) {
      expect(
        () => DirectoryPack(invalid),
        throwsA(isA<DirectoryException>()),
      );
    }
  });
  test(
    'catalog resolves relative URL, rejects unsafe hashes and duplicates',
    () {
      final catalog = {
        'schema_version': 1,
        'packs': [
          Map<String, dynamic>.from(pack().json)..['url'] = 'pack.sqlite.gz',
        ],
      };
      expect(
        parseDirectoryCatalog(
          catalog,
          base: Uri.parse('https://example.org/v1/catalog.json'),
        ).single.url.toString(),
        'https://example.org/v1/pack.sqlite.gz',
      );
      expect(
        () => DirectoryPack({...pack().json, 'sqlite_sha256': '../escape'}),
        throwsA(isA<DirectoryException>()),
      );
      expect(
        () => parseDirectoryCatalog({
          'schema_version': 1,
          'packs': [pack().json, pack().json],
        }),
        throwsA(isA<DirectoryException>()),
      );
    },
  );
}
