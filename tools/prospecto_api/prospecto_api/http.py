"""WSGI interface. Local preview uses wsgiref; deployment uses Gunicorn/proxy."""
from collections import OrderedDict
import json
import os
from pathlib import Path
import re
import threading
import time
from urllib.parse import parse_qsl

from .store import DirectoryStore, QueryError, QueryTimeout

PHRASES = {200: 'OK', 206: 'Partial Content', 304: 'Not Modified', 400: 'Bad Request',
           404: 'Not Found', 405: 'Method Not Allowed', 416: 'Range Not Satisfiable',
           429: 'Too Many Requests', 503: 'Service Unavailable'}


class RateLimit:
    def __init__(self, rate=10, burst=20):
        self.rate, self.burst = rate, burst
        self.clients = OrderedDict()
        self.lock = threading.Lock()

    def accept(self, client):
        stamp = time.monotonic()
        with self.lock:
            tokens, before = self.clients.pop(client, (self.burst, stamp))
            tokens = min(self.burst, tokens + (stamp - before) * self.rate)
            allowed = tokens >= 1
            self.clients[client] = (tokens - 1 if allowed else tokens, stamp)
            while len(self.clients) > 4096:
                self.clients.popitem(last=False)
            return allowed


class FileBody:
    def __init__(self, path, start, length):
        self.stream = path.open('rb')
        self.stream.seek(start)
        self.remaining = length

    def __iter__(self):
        return self

    def __next__(self):
        if self.remaining <= 0:
            self.close()
            raise StopIteration
        chunk = self.stream.read(min(128 * 1024, self.remaining))
        if not chunk:
            self.close()
            raise StopIteration
        self.remaining -= len(chunk)
        return chunk

    def close(self):
        self.stream.close()


class API:
    def __init__(self, store, *, limiter=None, accel_prefix=None):
        self.store = store
        self.limiter = limiter or RateLimit()
        self.accel_prefix = accel_prefix
        if accel_prefix and not re.fullmatch(r'/[A-Za-z0-9_/-]+/', accel_prefix):
            raise ValueError('Unsafe internal download prefix.')

    def __call__(self, environ, start_response):
        method, path = environ.get('REQUEST_METHOD', 'GET'), environ.get('PATH_INFO', '/')
        common = [('X-Content-Type-Options', 'nosniff'), ('Referrer-Policy', 'no-referrer')]

        def respond(code, payload=None, headers=(), body=None):
            if body is None:
                content = b'' if payload is None else json.dumps(payload, ensure_ascii=False, allow_nan=False).encode('utf-8')
                body = [content]
                headers = [*headers, ('Content-Type', 'application/json; charset=utf-8'), ('Content-Length', str(len(content)))]
            start_response(f'{code} {PHRASES[code]}', [*common, *headers])
            return [] if method == 'HEAD' else body

        try:
            if method not in ('GET', 'HEAD'):
                return respond(405, {'error': 'Lecture seule.'}, [('Allow', 'GET, HEAD')])
            if path not in ('/health', '/v1/status') and not self.limiter.accept(environ.get('REMOTE_ADDR', 'unknown')):
                return respond(429, {'error': 'Réessayez dans quelques instants.'}, [('Retry-After', '1')])
            if path in ('/health', '/v1/status'):
                return respond(200, self.store.status(), [('Cache-Control', 'no-store')])
            if path == '/v1/catalog':
                return respond(200, self.store.catalog(), [('Cache-Control', 'public, max-age=60')])
            if path == '/v1/territories':
                return respond(200, self.store.territories(), [('Cache-Control', 'public, max-age=60')])
            if path == '/v1/activities':
                return respond(200, {'activities': self.store.activities})
            if path == '/v1/search':
                query = environ.get('QUERY_STRING', '')
                if len(query) > 2048:
                    raise QueryError('Recherche trop longue.')
                try:
                    pairs = parse_qsl(query, keep_blank_values=True, max_num_fields=15)
                except ValueError:
                    raise QueryError('Trop de paramètres.') from None
                if len(dict(pairs)) != len(pairs):
                    raise QueryError('Paramètre répété.')
                return respond(200, self.store.search(dict(pairs)), [('Cache-Control', 'no-store')])
            match = re.fullmatch(r'/v1/packs/([A-Za-z0-9._-]+)/([0-9a-f]{64})\.sqlite\.gz', path)
            if match:
                pack = self.store.by_id.get(match[1])
                if pack is None or pack['metadata']['gzip_sha256'] != match[2]:
                    return respond(404, {'error': 'Pack inconnu.'})
                file = self.store._unchanged(pack, 'gzip')
                size = pack['metadata']['gzip_size_bytes']
                etag = '"' + match[2] + '"'
                cache = [('ETag', etag), ('Cache-Control', 'public, max-age=31536000, immutable'),
                         ('Accept-Ranges', 'bytes')]
                if environ.get('HTTP_IF_NONE_MATCH') == etag:
                    return respond(304, headers=cache, body=[])
                if self.accel_prefix:
                    return respond(200, headers=[*cache, ('Content-Type', 'application/gzip'),
                        ('X-Accel-Redirect', self.accel_prefix + self.store.version + '/blobs/' + file.name)], body=[])
                start, end, code = 0, size - 1, 200
                requested = environ.get('HTTP_RANGE')
                if requested:
                    byte_range = re.fullmatch(r'bytes=(\d+)-(\d*)', requested)
                    if not byte_range:
                        return respond(416, headers=[('Content-Range', f'bytes */{size}')], body=[])
                    start = int(byte_range[1])
                    end = min(int(byte_range[2]) if byte_range[2] else end, end)
                    if start > end or start >= size:
                        return respond(416, headers=[('Content-Range', f'bytes */{size}')], body=[])
                    code = 206
                    cache.append(('Content-Range', f'bytes {start}-{end}/{size}'))
                headers = [*cache, ('Content-Type', 'application/gzip'),
                           ('Content-Length', str(end - start + 1))]
                if method == 'HEAD':
                    return respond(code, headers=headers, body=[])
                return respond(code, headers=headers, body=FileBody(file, start, end - start + 1))
            return respond(404, {'error': 'Route inconnue.'})
        except (QueryError, ValueError) as error:
            if isinstance(error, QueryError):
                return respond(400, {'error': str(error)})
            # Internal paths and data diagnostics stay out of public responses.
            return respond(503, {'error': 'Publication indisponible, réessayez plus tard.'})
        except QueryTimeout as error:
            return respond(503, {'error': str(error)}, [('Retry-After', '2')])
        except Exception:
            return respond(503, {'error': 'Annuaire temporairement indisponible.'})


def create_app():
    data = os.environ.get('PROSPECTO_DATA_DIR')
    if not data:
        raise RuntimeError('PROSPECTO_DATA_DIR must identify a verified API publication.')
    return API(DirectoryStore(Path(data)), accel_prefix=os.environ.get('PROSPECTO_ACCEL_PREFIX'))
