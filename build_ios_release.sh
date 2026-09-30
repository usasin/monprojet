#!/usr/bin/env bash
set -euo pipefail
script_dir="${BASH_SOURCE[0]%/*}"
if [[ "$script_dir" == "${BASH_SOURCE[0]}" ]]; then script_dir=.; fi
cd "$script_dir"

# Public AdMob identifiers created for Prospecto iOS; CI may override them.
ADMOB_IOS_APP_ID="${ADMOB_IOS_APP_ID-ca-app-pub-1360261396564293~5907234032}"
ADMOB_IOS_BANNER_ID="${ADMOB_IOS_BANNER_ID-ca-app-pub-1360261396564293/9926370092}"
ADMOB_IOS_INTERSTITIAL_ID="${ADMOB_IOS_INTERSTITIAL_ID-ca-app-pub-1360261396564293/4594152361}"
[[ "$ADMOB_IOS_APP_ID" =~ ^ca-app-pub-[0-9]+~[0-9]+$ ]] || exit 1
for unit in "$ADMOB_IOS_BANNER_ID" "$ADMOB_IOS_INTERSTITIAL_ID"; do
  [[ "$unit" =~ ^ca-app-pub-[0-9]+/[0-9]+$ ]] || exit 1
  case "$unit" in
    ca-app-pub-3940256099942544/*|ca-app-pub-1360261396564293/1162631714|ca-app-pub-1360261396564293/5482834887)
      echo 'Use production iOS ad units, not Android or test IDs.' >&2; exit 1 ;;
  esac
done
case "$ADMOB_IOS_APP_ID" in
  ca-app-pub-3940256099942544~*|ca-app-pub-1360261396564293~6577474458)
    echo 'Use the production iOS AdMob application ID.' >&2; exit 1 ;;
esac

printf 'ADMOB_APP_ID = %s\n' "$ADMOB_IOS_APP_ID" > ios/Flutter/AdMob.local.xcconfig
flutter pub get
flutter build ipa --release \
  --dart-define-from-file=config/prod.json \
  --dart-define=ADMIN_TEST_MODE=false \
  --dart-define=ADMOB_PRODUCTION_ENABLED=true \
  --dart-define="ADMOB_IOS_BANNER_ID=$ADMOB_IOS_BANNER_ID" \
  --dart-define="ADMOB_IOS_INTERSTITIAL_ID=$ADMOB_IOS_INTERSTITIAL_ID"
