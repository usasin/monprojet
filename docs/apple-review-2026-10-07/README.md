# Prospecto iOS review correction — 7 October 2026

Base: successful Codemagic build #9, 4 October 2026, app 1.6.0 (52).
Exact compiled source: `311788effeeda48fc69b096341f141292deb8047`, branch `prospecto-ios-1.6.0-52`.
Restore restored only pub/CocoaPods caches. The checkout/preflight/IPA logs and downloaded IPA identify this source and version.

## Applied code changes

- Native Apple login alongside Google in the login screen and login sheet; request email/name scopes, use the existing FirebaseAuth provider flow, permit retry after cancellation.
- On Apple platforms, display Premium information immediately and load the StoreKit catalogue independently of cloud entitlement synchronization. No automatic restoration on opening; the existing explicit Restore and server purchase validation remain in place.
- Bound store availability and catalogue queries, treat an empty catalogue as unavailable, retain the purchase listener across retries, show localized prices only when returned by the store, and provide Retry.
- Regression tests cover cancellation, Android login visibility, empty/pending StoreKit, retry, purchase events and phone/tablet layouts.

## Prepared, not applied: required entitlement link

The build-52 provisioning profile already contains `com.apple.developer.applesignin = [Default]`. The Runner executable signed into the IPA does not contain this entitlement. The source `ios/Runner/Runner.entitlements` already contains it, but no Runner configuration references the file.

`enable-existing-apple-entitlements.patch` adds only `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to the three Runner configurations. It does not change the certificate, provisioning profile, team, Bundle ID, Firebase configuration or workflow. It has been checked with `git apply --check --unidiff-zero`, but is deliberately not applied because the current instruction forbids signing changes.

After approval, apply with:

```sh
git apply --unidiff-zero docs/apple-review-2026-10-07/enable-existing-apple-entitlements.patch
```

Before any new build: verify that the Apple provider is enabled in the existing Firebase project; no Firebase configuration was changed here. After the next authorized native build, verify the signed entitlement and test real Apple login, privacy relay, StoreKit catalogue/purchase/restore in Sandbox on iPhone and iPad. Flutter tests do not establish native Sandbox success.

The original workflow, signing files, app version, Bundle ID and Firebase project remain unchanged. No Codemagic build or review submission of the rejected binary is authorized by this correction branch.

## Local validation

Validated with Flutter 3.44.8 / Dart 3.12.2, without compiling an iOS binary:

- Focused Apple review, billing and purchase validation tests: 15 passed.
- Complete `flutter test --no-pub` suite: 110 passed.
- `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`: exit 0, no errors; 622 warning/info findings remain in the project.
- `python tools/verify_ios_source.py`: passed for 1.6.0+52.
- `git diff --check` and the unapplied entitlement patch's `git apply --check --unidiff-zero`: passed.
- The original dependency lockfile is retained; SDK-generated dependency resolution changes are not included.

The regression tests use a fake store and mocked authentication cancellation. They verify loading, retries, localized store prices, purchase event handling and responsive layouts, not native Apple authentication or actual Sandbox purchases.
