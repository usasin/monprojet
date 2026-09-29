#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-}"
if [[ -z "$EMAIL" ]]; then
  read -r -p "Adresse e-mail du compte développeur Prospecto : " EMAIL
fi

cd "$(dirname "$0")/functions"
npm ci
node scripts/grant-developer-access.mjs "$EMAIL" revoke

echo "Accès développeur retiré. Déconnectez puis reconnectez le compte."
