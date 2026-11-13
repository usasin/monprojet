"""Prepare public static downloads. No web server, account, upload or network call."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
from urllib.parse import quote

HERE = Path(__file__).resolve().parent
for folder in ('prospecto-api', 'prospecto_api'):
    candidate = HERE.parent / folder
    if (candidate / 'prospecto_api/prepare.py').is_file():
        sys.path.insert(0, str(candidate))
        break
# Reuse the tested OFFLINE public-pack verifier; no API service is started.
from prospecto_api.prepare import prepare
from prospecto_api.store import IDENTIFIER, sha256

MAX_GZIP = 512 * 1024**2
MAX_SQLITE = 2 * 1024**3


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def build(catalog_path, output, repository, *, free_floor=4 * 1024**3):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9_.-]{1,100}', repository):
        raise ValueError('Dépôt attendu : proprietaire/nom, sans URL ni chemin local.')
    source, target = Path(catalog_path).resolve(), Path(output).resolve()
    if target.exists():
        raise ValueError('Le dossier de livraison existe déjà ; aucune version ne sera écrasée.')
    if source.stat().st_size > 4 * 1024**2:
        raise ValueError('Catalogue trop volumineux.')
    catalog = json.loads(source.read_text(encoding='utf-8'))
    version = catalog.get('version', '')
    if catalog.get('schema_version') != 1 or not IDENTIFIER.fullmatch(version):
        raise ValueError('Catalogue ou version invalide.')
    packs = catalog.get('packs')
    if not isinstance(packs, list) or not 1 <= len(packs) <= 512:
        raise ValueError('Liste de territoires invalide.')
    helper = next((p for p in packs if p.get('department')), None)
    if helper is None:
        raise ValueError('Un pack départemental est requis dans cette publication.')
    seen, departments, names = set(), set(), set()
    for pack in packs:
        ident = pack.get('pack_id', '')
        filename = pack.get('url', '')
        if not IDENTIFIER.fullmatch(ident) or ident in seen or pack.get('version') != version:
            raise ValueError('Identifiant, doublon ou version incohérente.')
        if not isinstance(filename, str) or not re.fullmatch(r'[A-Za-z0-9_.-]+\.sqlite\.gz', filename) or filename in names:
            raise ValueError('Fichier local de pack requis, sans chemin externe ni doublon.')
        if pack.get('is_demo') is not False:
            raise ValueError('Les données fictives sont interdites dans cette diffusion.')
        if (type(pack.get('gzip_size_bytes')) is not int or not 0 < pack['gzip_size_bytes'] <= MAX_GZIP or
            type(pack.get('sqlite_size_bytes')) is not int or not 0 < pack['sqlite_size_bytes'] <= MAX_SQLITE):
            raise ValueError('Pack trop volumineux pour cette diffusion mobile.')
        department = pack.get('department')
        if department:
            if department in departments:
                raise ValueError('Département dupliqué.')
            departments.add(department)
        local = (source.parent / filename).resolve()
        if local.parent != source.parent or local.stat().st_size != pack['gzip_size_bytes'] or sha256(local) != pack['gzip_sha256']:
            raise ValueError('Archive source non conforme.')
        seen.add(ident)
        names.add(filename)
    total = sum(p['gzip_size_bytes'] for p in packs)
    largest = max(p['sqlite_size_bytes'] for p in packs)
    largest_gzip = max(p['gzip_size_bytes'] for p in packs)
    target.parent.mkdir(parents=True, exist_ok=True)
    # One territory at a time, plus one department used by the region verifier.
    required = total + 2 * largest + 4 * largest_gzip + free_floor
    if shutil.disk_usage(target.parent).free < required:
        raise ValueError('Espace insuffisant pour les archives, la vérification et la réserve disque.')
    stage = Path(tempfile.mkdtemp(prefix='.static-stage-', dir=target.parent))
    try:
        (stage / 'assets').mkdir()
        public = []
        for index, pack in enumerate(packs):
            if shutil.disk_usage(target.parent).free < 2 * largest + 4 * largest_gzip + free_floor:
                raise ValueError('Réserve disque atteinte ; arrêt sans activation.')
            # The original inputs are read only. Temporary validation never
            # touches D: or creates a work DB beside the user's source files.
            with tempfile.TemporaryDirectory(prefix='.verify-', dir=stage) as temporary:
                temp = Path(temporary)
                subset = [pack] if pack.get('department') else [helper, pack]
                for item in subset:
                    shutil.copyfile(source.parent / item['url'], temp / item['url'])
                write_json(temp / 'catalog.json', {**catalog, 'packs': subset})
                verified = prepare(temp / 'catalog.json', temp / 'checked')
                result = next(p for p in verified['packs'] if p['metadata']['pack_id'] == pack['pack_id'])
                metadata = dict(result['metadata'])
                blob = temp / 'checked/releases' / version / result['gzip']
                filename = pack['url']
                destination = stage / 'assets' / filename
                shutil.copyfile(blob, destination)
                if sha256(destination) != metadata['gzip_sha256']:
                    raise ValueError('Copie finale non conforme.')
                metadata['url'] = f'https://github.com/{repository}/releases/download/{quote(version, safe="")}/{quote(filename, safe="")}'
                public.append(metadata)
        published_catalog = {'schema_version': 1, 'version': version,
                             'data_date': catalog['data_date'], 'is_demo': False,
                             'energy_enabled': False, 'packs': public}
        catalog_relative = f'versions/{version}/catalog.json'
        catalog_file = stage / 'repo' / catalog_relative
        write_json(catalog_file, published_catalog)
        write_json(stage / 'repo/current.json', {'schema_version': 1, 'version': version,
                   'catalog': catalog_relative, 'catalog_sha256': sha256(catalog_file)})
        rows = sum(p['rows'] for p in public if p['department'])
        licenses = sorted({str(license) for p in public for license in p['source_licenses']})
        (stage / 'repo/SOURCE_LICENSES.md').write_text(
            '# Sources des packs publics\n\n' + '\n'.join('- ' + x for x in licenses) +
            '\n\nSources : [INSEE SIRENE](https://www.insee.fr/fr/information/3591226).'
            '\nProvenance et dates détaillées conservées dans les packs.\n', encoding='utf-8', newline='\n')
        (stage / 'repo/README.md').write_text(
            '# Prospecto — packs de prospection\n\n'
            f'Version {version}, données du {catalog["data_date"]}. '
            f'{rows} établissements publics réels répartis sur {len(departments)} département(s).\n\n'
            'Les fichiers se téléchargent dans Prospecto puis se consultent localement. '
            'Aucune API ni ordinateur personnel ne doit rester démarré pour les servir.\n\n'
            'La couverture de chaque territoire est indiquée dans son catalogue. '
            'Un extrait partiel ne représente pas le département entier. '
            'Cette publication ne contient aucune observation énergétique, donnée de CRM privé, '
            'base de travail ou code de l’application Flutter.\n', encoding='utf-8', newline='\n')
        files = [{'path': p.relative_to(stage).as_posix(), 'bytes': p.stat().st_size,
                  'sha256': sha256(p)} for p in sorted(stage.rglob('*')) if p.is_file()]
        report = {'prepared_at_utc': datetime.now(timezone.utc).isoformat(),
                  'repository_proposed': repository, 'published': False, 'energy_enabled': False,
                  'version': version, 'department_count': len(departments),
                  'establishments': rows, 'gzip_bytes': total,
                  'catalog_url_after_publication': f'https://raw.githubusercontent.com/{repository}/main/current.json',
                  'files': files}
        write_json(stage / 'publication.json', report)
        if target.exists():
            raise ValueError('Une autre livraison a créé le dossier cible ; arrêt sans écrasement.')
        stage.rename(target)
        return report
    finally:
        if stage.exists():
            if stage.resolve().parent != target.parent or not stage.name.startswith('.static-stage-'):
                raise ValueError('Nettoyage hors dossier refusé.')
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description='Préparer les packs statiques publics Prospecto, sans API ni énergie.')
    parser.add_argument('--catalog', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--repository', required=True)
    args = parser.parse_args()
    report = build(args.catalog, args.output, args.repository)
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
