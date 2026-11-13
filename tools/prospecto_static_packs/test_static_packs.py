import json
import gzip
import hashlib
from pathlib import Path
import shutil
import sqlite3
import tempfile
import unittest
from static_packs import build, sha256

SAMPLE = Path(__file__).resolve().parents[1] / 'prospecto-api/sample_paris/catalog.json'
if not SAMPLE.is_file():
    SAMPLE = Path(__file__).resolve().parents[1] / 'prospecto_api/sample_paris/catalog.json'


class StaticPublication(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_real_pack_is_verified_and_only_static_public_files_are_prepared(self):
        target = self.root / 'delivery'
        result = build(SAMPLE, target, 'usasin/prospecto-directory-packs')
        self.assertFalse(result['published'])
        self.assertFalse(result['energy_enabled'])
        self.assertEqual(result['establishments'], 50)
        self.assertEqual(result['department_count'], 1)
        self.assertFalse(list(target.rglob('*.sqlite')))
        pointer = json.loads((target / 'repo/current.json').read_text(encoding='utf-8'))
        catalog_file = target / 'repo' / pointer['catalog']
        self.assertEqual(sha256(catalog_file), pointer['catalog_sha256'])
        # A Git UTF-8 text upload must preserve the exact pinned digest even
        # when files were prepared on Windows and uploaded from a text reader.
        self.assertNotIn(b'\r\n', catalog_file.read_bytes())
        self.assertEqual(sha256(catalog_file),
                         hashlib.sha256(catalog_file.read_text(encoding='utf-8').encode('utf-8')).hexdigest())
        pack = json.loads(catalog_file.read_text(encoding='utf-8'))['packs'][0]
        self.assertFalse(pack['coverage_complete'])
        self.assertTrue(pack['url'].startswith('https://github.com/usasin/prospecto-directory-packs/releases/download/'))
        for item in result['files']:
            self.assertEqual(sha256(target / item['path']), item['sha256'])
        self.assertEqual(len(list((target / 'assets').iterdir())), 1)

    def test_existing_delivery_is_never_overwritten(self):
        target = self.root / 'existing'
        target.mkdir()
        (target / 'keep.txt').write_text('keep', encoding='utf-8')
        with self.assertRaises(ValueError):
            build(SAMPLE, target, 'usasin/prospecto-directory-packs')
        self.assertEqual((target / 'keep.txt').read_text(), 'keep')

    def test_region_and_department_downloads_do_not_double_count_establishments(self):
        source = self.root / 'source'
        source.mkdir()
        catalog = json.loads(SAMPLE.read_text(encoding='utf-8'))
        department = catalog['packs'][0]
        shutil.copyfile(SAMPLE.parent / department['url'], source / department['url'])
        database = source / 'region.sqlite'
        database.write_bytes(gzip.decompress((source / department['url']).read_bytes()))
        db = sqlite3.connect(database)
        for key, value in [('pack_id', 'region-11'), ('department', ''), ('partition', 'region')]:
            db.execute('UPDATE pack_metadata SET value=? WHERE key=?', (value, key))
        db.commit()
        db.close()
        data = database.read_bytes()
        blob = gzip.compress(data)
        region = {**department, 'pack_id': 'region-11', 'department': '', 'partition': 'region',
                  'url': 'region-11.sqlite.gz', 'gzip_sha256': hashlib.sha256(blob).hexdigest(),
                  'gzip_size_bytes': len(blob), 'sqlite_sha256': hashlib.sha256(data).hexdigest(),
                  'sqlite_size_bytes': len(data)}
        (source / region['url']).write_bytes(blob)
        catalog['packs'].append(region)
        (source / 'catalog.json').write_text(json.dumps(catalog), encoding='utf-8')
        result = build(source / 'catalog.json', self.root / 'both', 'usasin/prospecto-directory-packs')
        self.assertEqual(result['establishments'], 50)
        self.assertEqual(result['department_count'], 1)
        self.assertEqual(len(list((self.root / 'both/assets').iterdir())), 2)
        self.assertFalse(list((self.root / 'both').rglob('*.sqlite')))

    def test_bad_repository_name_or_disk_budget_cannot_create_a_delivery(self):
        for repo in ['https://github.com/a/b', 'a/../../private', 'a/b?query']:
            with self.subTest(repo=repo), self.assertRaises(ValueError):
                build(SAMPLE, self.root / 'bad', repo)
        with self.assertRaises(ValueError):
            build(SAMPLE, self.root / 'no-space', 'usasin/prospecto-directory-packs', free_floor=10**18)
        self.assertFalse((self.root / 'no-space').exists())

    def test_tampered_input_is_not_published_and_source_is_preserved(self):
        source = self.root / 'source'
        source.mkdir()
        catalog = json.loads(SAMPLE.read_text(encoding='utf-8'))
        filename = catalog['packs'][0]['url']
        (source / filename).write_bytes(b'invalid')
        (source / 'catalog.json').write_text(json.dumps(catalog), encoding='utf-8')
        with self.assertRaises(ValueError):
            build(source / 'catalog.json', self.root / 'invalid', 'usasin/prospecto-directory-packs')
        self.assertEqual((source / filename).read_bytes(), b'invalid')
        self.assertFalse((self.root / 'invalid').exists())
        self.assertFalse(list(self.root.glob('.static-stage-*')))


if __name__ == '__main__':
    unittest.main()
