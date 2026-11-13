"""Real published sample plus synthetic edge cases; no network or private data."""
import copy
import gzip
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
import shutil
import sqlite3
import tempfile
import threading
import unittest
from urllib.request import urlopen
from wsgiref.simple_server import make_server, WSGIRequestHandler

from prospecto_api.http import API, RateLimit
from prospecto_api.prepare import prepare
from prospecto_api.store import DirectoryStore, EARTH, PUBLIC_FIELDS, QueryError, sha256

ROOT = Path(__file__).resolve().parents[1]
SAMPLE = ROOT / 'sample_paris/catalog.json'


def request(app, path, query='', method='GET', extra=None):
    captured = {}
    def begin(status, headers):
        captured.update(status=int(status.split()[0]), headers=dict(headers))
    env = {'PATH_INFO': path, 'QUERY_STRING': query, 'REQUEST_METHOD': method,
           'REMOTE_ADDR': 'test-client', 'wsgi.input': BytesIO(), **(extra or {})}
    body = app(env, begin)
    try:
        captured['body'] = b''.join(body)
    finally:
        if hasattr(body, 'close'):
            body.close()
    return captured


def encoded(data):
    return json.dumps(data, ensure_ascii=False).encode('utf-8')


def rewrite_sample(folder, version='fixture', mutate=None, *, extra_pack=False):
    """Mutate a private TEMP copy to exercise producer/publication boundaries."""
    source = json.loads(SAMPLE.read_text(encoding='utf-8'))
    original = source['packs'][0]
    database = folder / 'work.sqlite'
    database.write_bytes(gzip.decompress((SAMPLE.parent / original['url']).read_bytes()))
    db = sqlite3.connect(database)
    db.execute("UPDATE pack_metadata SET value=? WHERE key='version'", (version,))
    if mutate:
        mutate(db)
    db.commit()
    db.close()
    content = database.read_bytes()
    blob = gzip.compress(content)
    m = copy.deepcopy(original)
    m.update(version=version, sqlite_sha256=hashlib.sha256(content).hexdigest(),
             sqlite_size_bytes=len(content), gzip_sha256=hashlib.sha256(blob).hexdigest(),
             gzip_size_bytes=len(blob), url=version + '.sqlite.gz')
    (folder / m['url']).write_bytes(blob)
    catalog = {**source, 'version': version, 'packs': [m]}
    path = folder / 'catalog.json'
    path.write_bytes(encoded(catalog))
    return path


class RealSampleAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.data = Path(cls.temp.name) / 'data'
        prepare(SAMPLE, cls.data)
        cls.store = DirectoryStore(cls.data)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def app(self):
        return API(self.store, limiter=RateLimit(rate=1000, burst=1000))

    def test_health_is_explicit_about_partial_sample_and_energy(self):
        r = request(self.app(), '/health')
        data = json.loads(r['body'])
        self.assertEqual(r['status'], 200)
        self.assertEqual(data['available_establishments'], 50)
        self.assertEqual(data['available_departments'], ['75'])
        self.assertFalse(data['coverage_complete'])
        self.assertFalse(data['energy_enabled'])

    def test_whole_reference_does_not_claim_missing_departments_are_downloadable(self):
        r = json.loads(request(self.app(), '/v1/territories')['body'])
        self.assertEqual(len(r['departments']), 101)
        self.assertEqual(len(r['regions']), 18)
        paris = next(x for x in r['departments'] if x['code'] == '75')
        ardeche = next(x for x in r['departments'] if x['code'] == '07')
        self.assertTrue(paris['available'])
        self.assertFalse(ardeche['available'])
        self.assertEqual(ardeche['name'], 'Ardèche')
        self.assertIsNone(ardeche['rows'])

    def test_multi_activity_union_and_pagination_do_not_drop_results(self):
        rows = []
        for page in (1, 2):
            r = self.store.search({'activities': 'restaurant,grossiste boissons',
                                   'department': '75', 'page': str(page)})
            rows.extend(r['results'])
            self.assertEqual(r['pagination']['total'], 28)
        self.assertEqual(len(rows), 28)
        self.assertEqual(len({r['id'] for r in rows}), 28)
        self.assertEqual(len(self.store.search({'activities': 'CHR'})['results']), 25)
        self.assertEqual(self.store.search({'activities': 'CHR'})['pagination']['total'], 27)

    def test_geo_radius_returns_exact_circle_not_bbox_and_sorts_distance(self):
        result = self.store.search({'lat': '48.86', 'lon': '2.33', 'radius_m': '2000',
                                    'activities': 'restaurant', 'page_size': '100'})
        self.assertEqual(result['pagination']['total'], 19)
        distances = [r['distance_m'] for r in result['results']]
        self.assertEqual(distances, sorted(distances))
        self.assertLessEqual(max(distances), 2000)

    def test_unknown_territory_and_bad_numeric_values_are_rejected(self):
        for params in ({'department': '999'}, {'lat': 'NaN', 'lon': '2'},
                       {'lat': '48'}, {'lat': '48', 'lon': '2', 'radius_m': '999999'},
                       {'page': '-1'}, {'page': '99999'}, {'activities': 'unknown category'},
                       {'energy': 'all'}, {'naf': '56.10A OR 1=1'}):
            with self.subTest(params=params), self.assertRaises(QueryError):
                self.store.search(params)

    def test_unavailable_department_is_distinguished_from_no_businesses(self):
        r = self.store.search({'department': '13'})
        self.assertEqual(r['results'], [])
        self.assertEqual(r['coverage']['missing_departments'], ['13'])
        self.assertFalse(r['coverage']['complete'])

    def test_sql_injection_and_like_wildcards_are_literal(self):
        for text in ("' OR 1=1 --", '%', '_'):
            self.assertEqual(self.store.search({'q': text})['results'], [])
        self.assertEqual(self.store.search({})['pagination']['total'], 50)

    def test_existing_mobile_choices_and_naf_union_are_supported(self):
        for activity in ['coiffeur', 'garage', 'boulangerie', 'zone d’activités',
                         'TPE/PME', 'chemist', 'business park', 'beverage wholesaler', 'craftsman']:
            with self.subTest(activity=activity):
                self.store.search({'activities': activity})
        restaurant = self.store.search({'activities': 'restaurant', 'page_size': '100'})
        combined = self.store.search({'activities': 'restaurant,56.10A', 'page_size': '100'})
        self.assertEqual([r['siret'] for r in restaurant['results']],
                         [r['siret'] for r in combined['results']])
        self.assertEqual(self.store.search({'activities': 'restaurant,grossiste boissons,96.02A'})['pagination']['total'], 28)

    def test_exact_siret_siren_and_case_accent_folded_search(self):
        row = self.store.search({})['results'][0]
        exact = self.store.search({'q': row['siret']})
        self.assertEqual([r['siret'] for r in exact['results']], [row['siret']])
        self.assertTrue(all(r['siret'].startswith(row['siren']) for r in self.store.search({'q': row['siren']})['results']))
        folded = self.store.search({'q': 'pérnod ricard france'})
        self.assertGreater(folded['pagination']['total'], 0)
        self.assertEqual(folded, self.store.search({'q': 'PERNOD RICARD FRANCE'}))

    def test_responses_only_contain_public_business_fields(self):
        result = self.store.search({'page_size': '100'})
        self.assertEqual(set(result['results'][0]), set(PUBLIC_FIELDS) | {'distance_m'})
        for row in result['results']:
            self.assertFalse(any('energy' in key or 'consumption' in key or 'power_' in key for key in row))

    def test_direct_download_has_verified_bytes_range_and_cache(self):
        app = self.app()
        catalog = json.loads(request(app, '/v1/catalog')['body'])
        pack = catalog['packs'][0]
        r = request(app, pack['url'])
        self.assertEqual(r['status'], 200)
        self.assertEqual(hashlib.sha256(r['body']).hexdigest(), pack['gzip_sha256'])
        partial = request(app, pack['url'], extra={'HTTP_RANGE': 'bytes=17-44'})
        self.assertEqual(partial['status'], 206)
        self.assertEqual(partial['body'], r['body'][17:45])
        cached = request(app, pack['url'], extra={'HTTP_IF_NONE_MATCH': r['headers']['ETag']})
        self.assertEqual(cached['status'], 304)
        self.assertEqual(cached['body'], b'')
        head = request(app, pack['url'], method='HEAD')
        self.assertEqual(head['body'], b'')
        self.assertEqual(int(head['headers']['Content-Length']), len(r['body']))
        invalid = request(app, pack['url'], extra={'HTTP_RANGE': 'bytes=999999-'})
        self.assertEqual(invalid['status'], 416)

    def test_download_traversal_and_write_routes_are_not_exposed(self):
        app = self.app()
        for path in ('/v1/packs/../../private', '/v1/energy', '/admin', '/v1/packs/fr-75/' + '0'*64 + '.sqlite.gz'):
            self.assertEqual(request(app, path)['status'], 404)
        self.assertEqual(request(app, '/v1/search', method='POST')['status'], 405)

    def test_http_duplicate_and_unbounded_parameters_are_bad_requests(self):
        for query in ('department=75&department=13', 'energy=yes', '&'.join('x'+str(x)+'=1' for x in range(20)), 'q='+'a'*2100):
            self.assertEqual(request(self.app(), '/v1/search', query)['status'], 400)

    def test_rate_limit_is_bounded_and_provides_retry_after(self):
        app = API(self.store, limiter=RateLimit(rate=0, burst=1))
        self.assertEqual(request(app, '/v1/catalog')['status'], 200)
        blocked = request(app, '/v1/catalog')
        self.assertEqual(blocked['status'], 429)
        self.assertEqual(blocked['headers']['Retry-After'], '1')
        self.assertEqual(request(app, '/health')['status'], 200)

    def test_http_network_contract_with_real_server(self):
        class Quiet(WSGIRequestHandler):
            def log_message(self, *args):
                pass
        server = make_server('127.0.0.1', 0, self.app(), handler_class=Quiet)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with urlopen(f'http://127.0.0.1:{server.server_port}/v1/search?department=75&activities=GMS', timeout=5) as r:
                result = json.load(r)
            self.assertEqual(result['pagination']['total'], 6)
            self.assertEqual(len(result['results']), 6)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(5)


class PublicationSafety(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_demo_work_tables_private_columns_and_energy_are_rejected(self):
        mutations = [lambda db: db.execute('CREATE TABLE legal_units(siren TEXT)'),
                     lambda db: db.execute('CREATE TABLE private_customers(email TEXT)'),
                     lambda db: db.execute('ALTER TABLE establishments ADD COLUMN private_note TEXT'),
                     lambda db: db.execute("INSERT INTO energy_observations(id,scope,scope_id,status,source) VALUES ('e','department','75','verified','test')")]
        for index, change in enumerate(mutations):
            with self.subTest(index=index):
                catalog = rewrite_sample(self.source, 'blocked'+str(index), change)
                with self.assertRaises(ValueError):
                    prepare(catalog, self.root / ('out'+str(index)))
                self.assertFalse((self.root / ('out'+str(index)) / 'current.json').exists())
        catalog = rewrite_sample(self.source, 'demo')
        data = json.loads(catalog.read_text(encoding='utf-8'))
        data['packs'][0]['is_demo'] = True
        catalog.write_bytes(encoded(data))
        with self.assertRaises(ValueError):
            prepare(catalog, self.root / 'demo')

    def test_failed_new_version_does_not_replace_active_publication(self):
        output = self.root / 'data'
        prepare(SAMPLE, output)
        before = (output / 'current.json').read_bytes()
        catalog = rewrite_sample(self.source, 'broken')
        m = json.loads(catalog.read_text(encoding='utf-8'))['packs'][0]
        blob = self.source / m['url']
        content = bytearray(blob.read_bytes())
        content[-5] ^= 1
        blob.write_bytes(content)
        with self.assertRaises(ValueError):
            prepare(catalog, output)
        self.assertEqual((output / 'current.json').read_bytes(), before)
        self.assertFalse((output / 'releases/broken').exists())
        self.assertFalse(list(output.glob('.prepare-*')))

    def test_decompression_bound_and_external_source_paths_are_rejected(self):
        for index, value in enumerate((1, '../../outside.sqlite.gz')):
            catalog = rewrite_sample(self.source, 'invalid'+str(index))
            data = json.loads(catalog.read_text(encoding='utf-8'))
            field = 'sqlite_size_bytes' if index == 0 else 'url'
            data['packs'][0][field] = value
            catalog.write_bytes(encoded(data))
            with self.assertRaises(ValueError):
                prepare(catalog, self.root / ('out'+str(index)))

    def test_data_tampering_after_startup_is_refused_for_queries_and_downloads(self):
        output = self.root / 'data'
        prepare(SAMPLE, output)
        store = DirectoryStore(output)
        app = API(store)
        pack = store.department_packs[0]
        with pack['sqlite_path'].open('ab') as stream:
            stream.write(b'tampered')
        self.assertEqual(request(app, '/v1/search')['status'], 503)
        with pack['gzip_path'].open('ab') as stream:
            stream.write(b'tampered')
        self.assertEqual(request(app, store.catalog()['packs'][0]['url'])['status'], 503)

    def test_accel_download_only_uses_verified_opaque_blob_name(self):
        output = self.root / 'data'
        prepare(SAMPLE, output)
        store = DirectoryStore(output)
        result = request(API(store, accel_prefix='/_packs/'), store.catalog()['packs'][0]['url'])
        self.assertEqual(result['status'], 200)
        self.assertEqual(result['body'], b'')
        self.assertEqual(result['headers']['X-Accel-Redirect'],
                         '/_packs/' + store.version + '/blobs/' + store.packs[0]['gzip_path'].name)

    def test_duplicate_department_and_wrong_region_are_rejected(self):
        for index in (0, 1):
            catalog = rewrite_sample(self.source, 'duplicate'+str(index))
            data = json.loads(catalog.read_text(encoding='utf-8'))
            if index == 0:
                duplicate = {**data['packs'][0], 'pack_id': 'other-paris'}
                data['packs'].append(duplicate)
            else:
                data['packs'][0]['region'] = '84'
            catalog.write_bytes(encoded(data))
            with self.assertRaises(ValueError):
                prepare(catalog, self.root / ('out'+str(index)))


if __name__ == '__main__':
    unittest.main()
