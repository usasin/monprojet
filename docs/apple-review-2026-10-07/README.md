# Prospecto iOS review correction — 7 October 2026

Base: successful Codemagic build #9, 4 October 2026, app 1.6.0 (52).
Exact compiled source: `311788effeeda48fc69b096341f141292deb8047`, branch `prospecto-ios-1.6.0-52`.
Restore restored only pub/CocoaPods caches. The checkout/preflight/IPA logs and downloaded IPA identify this source and version.

## Applied code changes

- Native Apple login alongside Google in the login screen and login sheet; request email/name scopes, use the existing FirebaseAuth provider flow, permit retry after cancellation.
- On Apple platforms, display Premium information immediately and load the StoreKit catalogue independently of cloud entitlement synchronization. No automatic restoration on opening; the existing explicit Restore and server purchase validation remain in place.
- Bound store availability and catalogue queries, treat an empty catalogue as unavailable, retain the purchase listener across retries, show localized prices only when returned by the store, and provide Retry.
- Regression tests cover cancellation, Android login visibility, empty/pending StoreKit, retry, purchase events and phone/tablet layouts.

## Applied after user authorization: required entitlement link

The build-52 provisioning profile already contains `com.apple.developer.applesignin = [Default]`. The Runner executable signed into the IPA does not contain this entitlement. The source `ios/Runner/Runner.entitlements` already contains it, but no Runner configuration references the file.

The user authorized completing the necessary corrections on 7 October. The three Runner configurations now reference `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;`. The certificate, provisioning profile, team, Bundle ID, Firebase configuration and workflow are unchanged.

The stored patch records the three-line change already applied. Do not apply it again. Its reverse application is checked with:

```sh
git apply --reverse --check --unidiff-zero docs/apple-review-2026-10-07/enable-existing-apple-entitlements.patch
```

The existing native source preflight now verifies the entitlement file and all three Runner references. The existing IPA verifier also checks the actual signed application's Apple entitlement and its provisioning profile, so a missing native entitlement cannot produce another green archive. This does not change the workflow or regenerate signing assets.

The Apple provider was verified enabled in the existing `quiz-commercial` Firebase project on 7 October. No Firebase configuration was changed here. After the next authorized native build, test real Apple login, privacy relay, StoreKit catalogue/purchase/restore in Sandbox on iPhone and iPad. Flutter tests do not establish native Sandbox success.

## Next native build and review

Use the review correction source based on successful build #9 with the `prospecto-ios` workflow, retaining its dependency caches and signing assets. On 8 October, the screenshot generation step was removed from this archive workflow after build #10 timed out while launching the iPad capture flow. All four iPhone captures in that run passed; the existing product-page and IAP review screenshots remain in App Store Connect. Regenerate screenshots separately when their screens actually change. The existing script selects the next unused App Store build number automatically. Verify the archive with the strengthened signed-IPA check before uploading it, then test Apple login and subscription catalogue/purchase/restore on iPhone and iPad.

The monthly and annual products and Premium group are in the existing App Store Connect review draft, all marked Ready for Review, with review metadata and screenshots. They have not been submitted. Add the corrected app version to the same submission after native validation; do not resubmit the rejected build 52. The user's 7 October screenshots confirm that the paid-app agreement, bank account, US tax forms and compliance requirements are active.

Build #10 (`6ac71b38de4f6899ca0d1391`) timed out before creating an IPA and uploaded no replacement binary. The 8 October retry is authorized by the user and removes only screenshot generation and its artifact globs from the workflow. Signing assets, SDK settings, caches, app version, Bundle ID, Firebase, analysis, tests, archive validation and publishing settings are retained. The rejected binary has not been resubmitted. The existing build-number script automatically selects a number higher than the latest uploaded build; no manual version change is needed.

## Local validation

Validated with Flutter 3.44.8 / Dart 3.12.2, without compiling an iOS binary:

- Focused Apple review, billing and purchase validation tests: 15 passed.
- Complete `flutter test --no-pub` suite: 110 passed.
- `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`: exit 0, no errors; 622 warning/info findings remain in the project.
- `python tools/verify_ios_source.py`: passed for 1.6.0+52.
- `git diff --check` and the applied entitlement patch's reverse application check: passed.
- Updated Python validators compile; the native source validator passes with all three Apple entitlement references. The IPA validator still requires a future native archive on macOS.
- The original dependency lockfile is retained; SDK-generated dependency resolution changes are not included.

The regression tests use a fake store and mocked authentication cancellation. They verify loading, retries, localized store prices, purchase event handling and responsive layouts, not native Apple authentication or actual Sandbox purchases.
