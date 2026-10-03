#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${1:-quiz-commercial}"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(mktemp -d /tmp/prospecto-sales-deploy.XXXXXX)"
export npm_config_cache="/tmp/prospecto-npm-cache"
cp "$SOURCE_DIR/firebase.json" "$SOURCE_DIR/firestore.rules" "$SOURCE_DIR/firestore.indexes.json" "$SOURCE_DIR/storage.rules" "$DEPLOY_DIR/"
mkdir "$DEPLOY_DIR/functions"
cp "$SOURCE_DIR/functions/package.json" "$SOURCE_DIR/functions/package-lock.json" "$SOURCE_DIR/functions/tsconfig.json" "$DEPLOY_DIR/functions/"
cp -R "$SOURCE_DIR/functions/src" "$DEPLOY_DIR/functions/"
cd "$DEPLOY_DIR/functions"
npm ci
npm run build
cd "$DEPLOY_DIR"
npx --yes firebase-tools deploy --project "$PROJECT_ID" --only functions:saveSalesOpportunity,functions:updateEnterpriseDisplaySettings,functions:deleteEnterpriseRecord,functions:revokeOrgInvite
npx --yes firebase-tools deploy --project "$PROJECT_ID" --only firestore:rules,firestore:indexes
printf 'Backend 1.6.0 déployé sur %s. Dossier temporaire : %s\n' "$PROJECT_ID" "$DEPLOY_DIR"
