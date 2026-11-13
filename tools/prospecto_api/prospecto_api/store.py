from __future__ import annotations

import hashlib
import heapq
import json
import math
from pathlib import Path
import re
import sqlite3
import time
import unicodedata

EARTH = 6371000.0
PUBLIC_FIELDS = ('id', 'siret', 'siren', 'name', 'address', 'postal_code',
                 'commune_code', 'department', 'region', 'lat', 'lon',
                 'naf_code', 'naf_version', 'employee_band', 'enterprise_size',
                 'source', 'source_date', 'geo_quality')
IDENTIFIER = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$')
# Additional existing app choices, strictly scoped to the current NAF Rev.2.
NAF_ACTIVITIES = {
    'hairdressers': {'label': 'Coiffure', 'synonyms': ['coiffeur', 'coiffure', 'hairdresser', 'barber', 'barbier'], 'naf_codes': ['96.02A']},
    'vehicle_repair': {'label': 'Garages', 'synonyms': ['garage', 'garages'], 'naf_codes': ['45.20A', '45.20B']},
    'bakeries': {'label': 'Boulangeries', 'synonyms': ['boulanger', 'boulangerie', 'boulangeries'], 'naf_codes': ['10.71C']},
}


class QueryError(ValueError):
    pass


class QueryTimeout(RuntimeError):
    pass


def sha256(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def contained(base: Path, relative: str) -> Path:
    value = base.joinpath(relative).resolve()
    if not value.is_relative_to(base.resolve()) or Path(relative).is_absolute():
        raise ValueError('Path outside the published release.')
    return value


def normalize(value: str) -> str:
    value = value.replace('’', "'").replace('ʼ', "'")
    return ' '.join(''.join(c for c in unicodedata.normalize('NFKD', value.casefold())
                           if not unicodedata.combining(c)).split())


def distance(lat, lon, other_lat, other_lon):
    a, b = math.radians(other_lat - lat), math.radians(other_lon - lon)
    h = math.sin(a / 2)**2 + math.cos(math.radians(lat)) * math.cos(math.radians(other_lat)) * math.sin(b / 2)**2
    return EARTH * 2 * math.asin(math.sqrt(min(1.0, max(0.0, h))))


def bounds(lat, lon, radius):
    angular = radius / EARTH
    dy = math.degrees(angular)
    if abs(lat) + dy >= 90:
        return max(-90, lat - dy), min(90, lat + dy), None
    dx = math.degrees(math.asin(min(1, math.sin(angular) / math.cos(math.radians(lat)))))
    return lat - dy, lat + dy, (lon - dx, lon + dx)


class DirectoryStore:
    """No private intake, work DB, third-party lookup or energy query here."""
    max_offset = 2000

    def __init__(self, data: str | Path, *, query_seconds=4):
        self.root = Path(data).resolve()
        current = json.loads((self.root / 'current.json').read_text(encoding='utf-8'))
        self.release = contained(self.root, current['store']).parent
        self.manifest = json.loads(contained(self.root, current['store']).read_text(encoding='utf-8'))
        if self.manifest.get('schema_version') != 1 or self.manifest.get('energy_enabled') is not False:
            raise ValueError('Unsupported API publication.')
        self.version = self.manifest['version']
        if not IDENTIFIER.fullmatch(self.version) or self.release.name != self.version:
            raise ValueError('Invalid publication version.')
        self.query_seconds = query_seconds
        self.packs = self.manifest['packs']
        self.department_packs = [p for p in self.packs if p['metadata']['department']]
        if not self.department_packs:
            raise ValueError('No department data available for search.')
        self.by_id = {}
        for pack in self.packs:
            m = pack['metadata']
            if not IDENTIFIER.fullmatch(m['pack_id']) or m['pack_id'] in self.by_id:
                raise ValueError('Invalid or duplicate pack identifier.')
            for field, digest_field, length_field in (
                ('gzip', 'gzip_sha256', 'gzip_size_bytes'),
                ('sqlite', 'sqlite_sha256', 'sqlite_size_bytes')):
                if pack.get(field) is None:
                    continue
                path = contained(self.release, pack[field])
                if path.stat().st_size != m[length_field] or sha256(path) != m[digest_field]:
                    raise ValueError('Published data checksum failed.')
                pack[field + '_path'] = path
                pack[field + '_fingerprint'] = (path.stat().st_size, path.stat().st_mtime_ns)
            self.by_id[m['pack_id']] = pack
        reference = self.manifest['reference']
        self.departments = reference['departments']
        self.regions = reference['regions']
        self.activities = [*reference['activities'],
                           *({'id': key, **value, 'naf_version': 'NAFRev2'} for key, value in NAF_ACTIVITIES.items())]
        self.aliases = {}
        for item in self.activities:
            for alias in [item['id'], item['label'], *item.get('synonyms', [])]:
                self.aliases[normalize(alias)] = item['id']
        self.aliases.update({'chemist': 'parapharmacy', 'business park': 'business_zones',
                             'beverage wholesaler': 'wholesale_beverages', 'craftsman': 'craft'})

    def _unchanged(self, pack, field):
        path = pack[field + '_path']
        stat = path.stat()
        if (stat.st_size, stat.st_mtime_ns) != pack[field + '_fingerprint']:
            raise ValueError('Publication changed; reload a verified release.')
        return path

    def catalog(self):
        packs = []
        for pack in self.packs:
            m = dict(pack['metadata'])
            m['url'] = f"/v1/packs/{m['pack_id']}/{m['gzip_sha256']}.sqlite.gz"
            packs.append(m)
        return {'schema_version': 1, 'version': self.version,
                'data_date': self.manifest['data_date'], 'is_demo': False,
                'energy_enabled': False, 'packs': packs}

    def territories(self):
        available = {p['metadata']['department']: p for p in self.department_packs}
        output = []
        for code, item in self.departments.items():
            pack = available.get(code)
            output.append({'code': code, 'name': item['name'], 'region': item['region'],
                           'available': pack is not None,
                           'rows': pack['rows'] if pack else None,
                           'pack_id': pack['metadata']['pack_id'] if pack else None,
                           'coverage_complete': bool(pack and pack['metadata']['coverage_complete'])})
        return {'version': self.version, 'departments': output,
                'regions': [{'code': k, 'name': v} for k, v in self.regions.items()]}

    def status(self):
        for pack in self.packs:
            for field in ('gzip', 'sqlite'):
                if pack.get(field):
                    self._unchanged(pack, field)
        return {'status': 'ready', 'version': self.version, 'energy_enabled': False,
                'coverage_complete': False,
                'available_departments': sorted(p['metadata']['department'] for p in self.department_packs),
                'available_establishments': sum(p['rows'] for p in self.department_packs),
                'data_date': self.manifest['data_date']}

    def search(self, params):
        allowed = {'department', 'region', 'activities', 'q', 'lat', 'lon', 'radius_m', 'page', 'page_size', 'naf'}
        if set(params) - allowed:
            raise QueryError('Paramètre de recherche inconnu.')
        try:
            page = int(params.get('page', '1'))
            size = int(params.get('page_size', '25'))
        except (ValueError, TypeError):
            raise QueryError('Pagination invalide.') from None
        offset = (page - 1) * size
        if page < 1 or not 1 <= size <= 100 or not 0 <= offset < self.max_offset:
            raise QueryError('Affinez la recherche : limite interactive de 2 000 résultats.')
        depts = {x.upper() for x in params.get('department', '').split(',') if x}
        regions = {x for x in params.get('region', '').split(',') if x}
        if len(depts) > 10 or depts - self.departments.keys() or regions - self.regions.keys():
            raise QueryError('Département ou région inconnu.')
        terms = [x.strip() for x in re.split('[,;|]', params.get('activities', '')) if x.strip()]
        if len(terms) > 12:
            raise QueryError('Choisissez au maximum douze activités.')
        categories, activity_nafs, explicit_nafs = set(), set(), set()
        for term in terms:
            if normalize(term) == 'tpe/pme':
                categories.update(x for x in ('micro_enterprises', 'sme') if any(a['id'] == x for a in self.activities))
            elif normalize(term) in self.aliases:
                ident = self.aliases[normalize(term)]
                if ident in NAF_ACTIVITIES:
                    activity_nafs.update(NAF_ACTIVITIES[ident]['naf_codes'])
                else:
                    categories.add(ident)
            elif re.fullmatch(r'\d{2}\.\d{2}[A-Z]', term.upper()):
                explicit_nafs.add(term.upper())
            else:
                raise QueryError('Activité inconnue : ' + term[:80])
        text = params.get('q', '').strip()
        if len(text) > 160:
            raise QueryError('Recherche textuelle trop longue.')
        codes = {x.upper() for x in params.get('naf', '').split(',') if x}
        if len(codes) > 30 or any(not re.fullmatch(r'\d{2}\.\d{2}[A-Z]', x) for x in codes):
            raise QueryError('Code NAF invalide.')
        center = None
        if 'lat' in params or 'lon' in params or 'radius_m' in params:
            try:
                lat, lon = float(params['lat']), float(params['lon'])
                radius = int(params.get('radius_m', '1000'))
            except (KeyError, ValueError, TypeError):
                raise QueryError('Latitude, longitude et rayon valides requis.') from None
            if not (math.isfinite(lat) and math.isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180 and 100 <= radius <= 50000):
                raise QueryError('Coordonnées ou rayon hors limites.')
            center = lat, lon, radius
        selected = [p for p in self.department_packs
                    if (not depts or p['metadata']['department'] in depts)
                    and (not regions or p['metadata']['region'] in regions)]
        deadline = time.monotonic() + self.query_seconds
        total, pooled = 0, []
        needed = min(offset + size + 1, self.max_offset)
        for pack in selected:
            if time.monotonic() > deadline:
                raise QueryTimeout('Recherche trop large, précisez le département ou le lieu.')
            path = self._unchanged(pack, 'sqlite')
            db = sqlite3.connect(path.as_uri() + '?mode=ro&immutable=1', uri=True)
            db.row_factory = sqlite3.Row
            try:
                db.execute('PRAGMA cache_size=-8192')
                db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
                clauses, values = ['e.active=1'], []
                activity_clauses = []
                if categories:
                    slots = ','.join('?' for _ in categories)
                    activity_clauses.append(f'EXISTS (SELECT 1 FROM establishment_categories c WHERE c.establishment_id=e.id AND c.category_id IN ({slots}))')
                    values.extend(sorted(categories))
                if activity_nafs:
                    activity_clauses.append("(e.naf_version='NAFRev2' AND e.naf_code IN (" + ','.join('?' for _ in activity_nafs) + '))')
                    values.extend(sorted(activity_nafs))
                if explicit_nafs:
                    activity_clauses.append('e.naf_code IN (' + ','.join('?' for _ in explicit_nafs) + ')')
                    values.extend(sorted(explicit_nafs))
                if activity_clauses:
                    clauses.append('(' + ' OR '.join(activity_clauses) + ')')
                if codes:
                    clauses.append('e.naf_code IN (' + ','.join('?' for _ in codes) + ')')
                    values.extend(sorted(codes))
                if text:
                    if re.fullmatch(r'\d{14}', text):
                        clauses.append('e.siret=?')
                        values.append(text)
                    elif re.fullmatch(r'\d{9}', text):
                        clauses.append('e.siret BETWEEN ? AND ?')
                        values.extend([text + '00000', text + '99999'])
                    else:
                        db.create_function('fold', 1, lambda x: normalize(x or ''), deterministic=True)
                        clauses.append("(fold(e.name) LIKE ? ESCAPE '\\' OR fold(e.address) LIKE ? ESCAPE '\\')")
                        escaped = normalize(text).replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
                        values.extend(['%' + escaped + '%', '%' + escaped + '%'])
                distance_select = 'NULL AS distance_m'
                order = 'e.department,e.id'
                if center:
                    lat, lon, radius = center
                    low, high, longitude = bounds(lat, lon, radius)
                    clauses.append('e.lat BETWEEN ? AND ?')
                    values.extend([low, high])
                    if longitude:
                        left, right = longitude
                        if left < -180:
                            clauses.append('(e.lon>=? OR e.lon<=?)')
                            values.extend([left + 360, right])
                        elif right > 180:
                            clauses.append('(e.lon>=? OR e.lon<=?)')
                            values.extend([left, right - 360])
                        else:
                            clauses.append('e.lon BETWEEN ? AND ?')
                            values.extend([left, right])
                    db.create_function('distance_m', 2, lambda a, b: distance(lat, lon, a, b), deterministic=True)
                    clauses.append('distance_m(e.lat,e.lon)<=?')
                    values.append(radius)
                    distance_select = 'distance_m(e.lat,e.lon) AS distance_m'
                    order = 'distance_m,e.department,e.id'
                where = ' AND '.join(clauses)
                total += db.execute('SELECT COUNT(*) FROM establishments e WHERE ' + where, values).fetchone()[0]
                columns = ','.join('e.' + x for x in PUBLIC_FIELDS)
                rows = db.execute(f'SELECT {columns},{distance_select} FROM establishments e WHERE {where} ORDER BY {order} LIMIT ?', [*values, needed])
                pooled.extend(dict(r) for r in rows)
                key = (lambda r: (r['distance_m'], r['department'], r['id'])) if center else (lambda r: (r['department'], r['id']))
                pooled = heapq.nsmallest(needed, pooled, key=key)
            except sqlite3.OperationalError as exc:
                if 'interrupted' in str(exc).lower():
                    raise QueryTimeout('Recherche trop large, précisez le lieu.') from None
                raise
            finally:
                db.close()
        items = pooled[offset:offset + size]
        for item in items:
            if item['distance_m'] is not None:
                item['distance_m'] = round(item['distance_m'], 1)
        available = {p['metadata']['department'] for p in selected}
        missing = sorted(depts - available)
        next_page = page + 1 if total > offset + size and offset + size < self.max_offset else None
        return {'version': self.version, 'results': items,
                'pagination': {'page': page, 'page_size': size, 'total': total,
                               'next_page': next_page, 'truncated': total > self.max_offset},
                'coverage': {'complete': False, 'available_departments': sorted(available),
                             'missing_departments': missing},
                'notice': 'Données disponibles dans votre annuaire ; couverture partielle. Aucun résultat ne prouve une absence d’entreprise.'}
