import argparse
from pathlib import Path
from wsgiref.simple_server import WSGIRequestHandler, make_server

from .http import API
from .prepare import prepare
from .store import DirectoryStore


class PrivateLocationLog(WSGIRequestHandler):
    def log_message(self, format, *args):
        # No request query, precise GPS, address, or client IP in preview logs.
        print('API preview request', flush=True)


def main():
    parser = argparse.ArgumentParser(description='Prospecto API B2B, sans énergie')
    commands = parser.add_subparsers(dest='command', required=True)
    build = commands.add_parser('prepare')
    build.add_argument('--catalog', type=Path, required=True)
    build.add_argument('--data', type=Path, required=True)
    serve = commands.add_parser('serve-local', help='Aperçu local uniquement ; utiliser Gunicorn et HTTPS en hébergement.')
    serve.add_argument('--data', type=Path, required=True)
    serve.add_argument('--port', type=int, default=59851)
    args = parser.parse_args()
    if args.command == 'prepare':
        manifest = prepare(args.catalog, args.data)
        print('Publication vérifiée :', manifest['version'])
    else:
        app = API(DirectoryStore(args.data))
        print(f'Aperçu local : http://127.0.0.1:{args.port} — couverture réelle selon /health.', flush=True)
        with make_server('127.0.0.1', args.port, app, handler_class=PrivateLocationLog) as server:
            server.serve_forever()


if __name__ == '__main__':
    main()
