#!/usr/bin/env bash
set -euo pipefail

EMAIL="${1:-}"
if [[ -z "$EMAIL" ]]; then
  read -r -p "Adresse e-mail du compte développeur Prospecto : " EMAIL
fi

cd "$(dirname "$0")/functions"
npm ci
npm run build
node scripts/grant-developer-access.mjs "$EMAIL" grant

echo "Accès développeur sécurisé accordé. Déconnectez puis reconnectez le compte dans Prospecto."
echo "Cela permet aussi de tester les entreprises Essentiel / Équipe / Business sans Stripe."
