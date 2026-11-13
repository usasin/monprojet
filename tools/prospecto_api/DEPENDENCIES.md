# Dépendance du serveur

Gunicorn 26.2.0, Python >=3.10. Vérifié le 6 novembre 2026 via les
[métadonnées officielles PyPI](https://pypi.org/pypi/gunicorn/26.2.0/json).
Cette version n'a aucune dépendance obligatoire sans extras. Le worker gthread
n'utilise aucun des extras facultatifs (gevent, HTTP/2, etc.).

La roue `gunicorn-26.2.0-py3-none-any.whl` fait 228389 octets, SHA256
`bd249d0b3f7972f7432f0a6b6ff3b3ee2d129f70cd1ff6c09a9dd9e29a2b88e3`.
L'installation du conteneur utilise `--require-hashes` et refuse d'autres octets.
Les tests locaux et la préparation des données utilisent uniquement la
bibliothèque standard Python. Gunicorn devra être lancé et validé sur Linux.
