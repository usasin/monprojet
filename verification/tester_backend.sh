#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
npm ci
(cd ../functions && npm ci && npm run build && node --test scripts/test-sales-logic.cjs)
export NODE_PATH="$PWD/node_modules"
export GCLOUD_PROJECT=demo-prospecto
./node_modules/.bin/firebase emulators:exec --project demo-prospecto --only firestore --config ../firebase.sales-tests.json "node --test ../functions/scripts/test-sales-emulator.cjs"
