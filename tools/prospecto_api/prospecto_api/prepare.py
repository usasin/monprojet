"""Verify public importer packs and atomically publish a business-only API release."""
from datetime import datetime, timezone
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import tempfile

from .store import IDENTIFIER, PUBLIC_FIELDS, sha256

MAX_GZIP = 2 * 1024**3
MAX_SQLITE = 8 * 1024**3
METADATA_FIELDS = ('schema_version', 'pack_id', 'version', 'department', 'region',
                   'partition', 'data_date', 'is_demo', 'coverage_complete',
                   'coverage_geojson', 'coverage_kind', 'source_licenses',
                   'categories_version', 'gzip_sha256', 'sqlite_sha256',
                   'gzip_size_bytes', 'sqlite_size_bytes', 'rows')


def prepare(catalog_path, output, reference=None):
    source = Path(catalog_path).resolve()
    if source.stat().st_size > 4 * 1024**2:
        raise ValueError('Catalogue supérieur à 4 Mo.')
    catalog = json.loads(source.read_text(encoding='utf-8'))
    version = catalog.get('version', '')
    if catalog.get('schema_version') != 1 or not IDENTIFIER.fullmatch(version):
        raise ValueError('Catalogue incompatible.')
    packs = catalog.get('packs')
    if not isinstance(packs, list) or not 1 <= len(packs) <= 512:
        raise ValueError('Liste de packs invalide.')
    reference_path = Path(reference) if reference else Path(__file__).with_name('reference.json')
    refs = json.loads(reference_path.read_text(encoding='utf-8'))
    root = Path(output).resolve()
    root.mkdir(parents=True, exist_ok=True)
    releases = root / 'releases'
    releases.mkdir(exist_ok=True)
    destination = releases / version
    if destination.exists():
        raise ValueError('Version déjà publiée : utilisez une version distincte.')
    staging = Path(tempfile.mkdtemp(prefix='.prepare-', dir=root))
    published = False
    try:
        (staging / 'blobs').mkdir()
        verified, seen, seen_departments = [], set(), set()
        for metadata in packs:
            m = {k: metadata[k] for k in METADATA_FIELDS if k in metadata}
            ident = m.get('pack_id', '')
            if not IDENTIFIER.fullmatch(ident) or ident in seen or m.get('version') != version:
                raise ValueError('Identifiant, doublon ou version de pack invalide.')
            seen.add(ident)
            if m.get('is_demo') is not False or not isinstance(m.get('coverage_complete'), bool):
                raise ValueError('Seuls les packs publics réels sont publiables.')
            if not isinstance(m.get('coverage_geojson'), dict) or not m.get('source_licenses'):
                raise ValueError('Couverture et licences requises.')
            department = m.get('department', '')
            if (department and department not in refs['departments']) or m.get('region') not in refs['regions']:
                raise ValueError('Territoire inconnu.')
            if department:
                if department in seen_departments or refs['departments'][department]['region'] != m['region']:
                    raise ValueError('Département dupliqué ou région incohérente.')
                seen_departments.add(department)
            for field in ('gzip_sha256', 'sqlite_sha256'):
                if not re.fullmatch('[0-9a-f]{64}', str(m.get(field, ''))):
                    raise ValueError('Empreinte invalide.')
            if type(m.get('gzip_size_bytes')) is not int or not 0 < m['gzip_size_bytes'] <= MAX_GZIP:
                raise ValueError('Archive trop volumineuse ou taille invalide.')
            if type(m.get('sqlite_size_bytes')) is not int or not 0 < m['sqlite_size_bytes'] <= MAX_SQLITE:
                raise ValueError('Base trop volumineuse ou taille invalide.')
            filename = metadata.get('url', '')
            if not isinstance(filename, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+\.sqlite\.gz', filename):
                raise ValueError('La préparation exige un fichier local de pack, pas une URL ni un chemin externe.')
            compressed = (source.parent / filename).resolve()
            if compressed.parent != source.parent or compressed.stat().st_size != m['gzip_size_bytes'] or sha256(compressed) != m['gzip_sha256']:
                raise ValueError('Archive source endommagée ou hors du dossier source.')
            # Never publish imported work tables or private app data. Exact gzip
            # bytes are checked before and after copying; original files untouched.
            gzip_name = 'blobs/' + m['gzip_sha256'] + '.sqlite.gz'
            target_gzip = staging / gzip_name
            if not target_gzip.exists():
                shutil.copyfile(compressed, target_gzip)
            if sha256(target_gzip) != m['gzip_sha256']:
                raise ValueError('Copie de l’archive non conforme.')
            sqlite_name = 'blobs/' + m['sqlite_sha256'] + '.sqlite'
            database = staging / sqlite_name
            if not database.exists():
                count = 0
                with gzip.open(target_gzip, 'rb') as incoming, database.open('xb') as outgoing:
                    while block := incoming.read(1024**2):
                        count += len(block)
                        if count > m['sqlite_size_bytes']:
                            raise ValueError('Décompression supérieure à la taille annoncée.')
                        outgoing.write(block)
                if count != m['sqlite_size_bytes'] or sha256(database) != m['sqlite_sha256']:
                    raise ValueError('Empreinte ou taille SQLite invalide.')
            db = sqlite3.connect(database.as_uri() + '?mode=ro&immutable=1', uri=True)
            try:
                if db.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
                    raise ValueError('Base SQLite endommagée.')
                tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                allowed_tables = {'pack_metadata', 'establishments', 'categories', 'establishment_categories',
                                  'energy_observations', 'provenance', 'business_events', 'equipment_observations',
                                  'corporate_facts', 'classification_evidence', 'establishment_geographies',
                                  'establishment_rtree', 'establishment_rtree_node', 'establishment_rtree_parent',
                                  'establishment_rtree_rowid', 'sqlite_sequence', 'sqlite_stat1', 'sqlite_stat4'}
                if tables - allowed_tables:
                    raise ValueError('Une base de travail ou privée ne doit jamais être publiée.')
                actual = dict(db.execute('SELECT key,value FROM pack_metadata'))
                for key in ('pack_id', 'version', 'department', 'region'):
                    if actual.get(key) != str(m[key]):
                        raise ValueError('Métadonnées SQLite différentes du catalogue.')
                if actual.get('is_demo') != 'false' or actual.get('coverage_complete') != str(m['coverage_complete']).lower():
                    raise ValueError('Couverture ou origine de la base incohérente.')
                if 'energy_observations' in tables and db.execute('SELECT 1 FROM energy_observations LIMIT 1').fetchone():
                    raise ValueError('Cette livraison B2B ne publie aucune observation énergétique.')
                columns = {r[1] for r in db.execute('PRAGMA table_info(establishments)')}
                if columns != set(PUBLIC_FIELDS) | {'active'}:
                    raise ValueError('Schéma de l’annuaire incompatible.')
                invalid = db.execute('SELECT 1 FROM establishments WHERE id IS NULL OR name IS NULL OR lat IS NULL OR lon IS NULL OR lat NOT BETWEEN -90 AND 90 OR lon NOT BETWEEN -180 AND 180 LIMIT 1').fetchone()
                if invalid:
                    raise ValueError('Établissement sans identifiant ou coordonnées valides.')
                rows = db.execute('SELECT COUNT(*) FROM establishments WHERE active=1').fetchone()[0]
                if type(m.get('rows')) is not int or rows != m['rows']:
                    raise ValueError('Nombre d’établissements différent du catalogue.')
                if department and db.execute('SELECT 1 FROM establishments WHERE department IS NULL OR department<>? LIMIT 1', (department,)).fetchone():
                    raise ValueError('Établissement hors du département annoncé.')
                if db.execute('PRAGMA foreign_key_check').fetchone():
                    raise ValueError('Relations SQLite incohérentes.')
            finally:
                db.close()
            verified.append({'metadata': m, 'gzip': gzip_name,
                             'sqlite': sqlite_name if department else None, 'rows': rows})
            if not department:
                # Region gzip remains downloadable; queries use department data
                # once, so overlapping department/region packs cannot duplicate rows.
                database.unlink()
        if not any(p['metadata']['department'] for p in verified):
            raise ValueError('Un pack départemental est requis pour la recherche.')
        manifest = {'schema_version': 1, 'version': version, 'data_date': catalog['data_date'],
                    'prepared_at_utc': datetime.now(timezone.utc).isoformat(),
                    'energy_enabled': False, 'packs': verified, 'reference': refs}
        (staging / 'store.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
        # mkdtemp is 0700 on Linux; published public files must also be readable
        # by the non-root API/container and the separate Nginx worker.
        for entry in staging.rglob('*'):
            entry.chmod(0o755 if entry.is_dir() else 0o644)
        staging.chmod(0o755)
        os.replace(staging, destination)
        published = True
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=root,
                                         prefix='.current-', suffix='.json', delete=False) as stream:
            part = Path(stream.name)
            json.dump({'version': version, 'store': f'releases/{version}/store.json'}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            part.chmod(0o644)
            os.replace(part, root / 'current.json')
        finally:
            part.unlink(missing_ok=True)
        return manifest
    finally:
        if not published and staging.exists():
            # Only the unique temporary directory created above is removed.
            if staging.resolve().parent != root or not staging.name.startswith('.prepare-'):
                raise ValueError('Unsafe staging cleanup refused.')
            shutil.rmtree(staging)
