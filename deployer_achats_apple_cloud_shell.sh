#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="${1:-quiz-commercial}"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_DIR="$(mktemp -d /tmp/prospecto-apple-deploy.XXXXXX)"
export npm_config_cache="/tmp/prospecto-npm-cache"
cp "$SOURCE_DIR/firebase.json" "$DEPLOY_DIR/"
mkdir "$DEPLOY_DIR/functions"
cp "$SOURCE_DIR/functions/package.json" "$SOURCE_DIR/functions/package-lock.json" "$SOURCE_DIR/functions/tsconfig.json" "$DEPLOY_DIR/functions/"
cp -R "$SOURCE_DIR/functions/src" "$SOURCE_DIR/functions/certificates" "$SOURCE_DIR/functions/scripts" "$DEPLOY_DIR/functions/"
cd "$DEPLOY_DIR/functions"
npm ci
npm run build
node --test scripts/test-apple-purchases.cjs scripts/test-sales-logic.cjs
cd "$DEPLOY_DIR"
npx --yes firebase-tools deploy --project "$PROJECT_ID" --only functions:getApplePurchaseAccount,functions:verifyApplePurchase,functions:appStoreNotifications,functions:verifyGooglePlayPurchase
printf 'Validation des achats Apple déployée sur %s. Dossier : %s\n' "$PROJECT_ID" "$DEPLOY_DIR"
