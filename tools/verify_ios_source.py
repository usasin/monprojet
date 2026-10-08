"""Fail before compilation if app identity or native configuration regresses."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
firebase = plistlib.loads((root / 'ios/Runner/GoogleService-Info.plist').read_bytes())
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
assert re.search(r'^version: 1\.6\.0\+52$', (root / 'pubspec.yaml').read_text(), re.M)
assert info['CFBundleDisplayName'] == 'Prospecto'
assert firebase['BUNDLE_ID'] == 'com.ainego.aiProspectGps'
assert firebase['PROJECT_ID'] == 'quiz-commercial'
assert info['GADApplicationIdentifier'] == 'ca-app-pub-1360261396564293~5907234032'
assert firebase['REVERSED_CLIENT_ID'] in info['CFBundleURLTypes'][0]['CFBundleURLSchemes']
assert project.count('GoogleService-Info.plist in Resources') >= 2
assert 'PRODUCT_BUNDLE_IDENTIFIER = com.ainego.aiProspectGps;' in project
assert len(info['UISupportedInterfaceOrientations~ipad']) == 4
entitlements = plistlib.loads((root / 'ios/Runner/Runner.entitlements').read_bytes())
assert entitlements.get('com.apple.developer.applesignin') == ['Default'], 'Apple login entitlement missing'
assert project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;') == 3, 'All three Runner configurations must include Apple login entitlements'
assert info['ITSAppUsesNonExemptEncryption'] is False
assert 'NSPhotoLibraryUsageDescription' in info
assert 'NSCameraUsageDescription' in info
for pattern in ['BEGIN PRIVATE KEY', 'BEGIN RSA PRIVATE KEY', 'sk_live_', 'sk_test_']:
    for file in [root / 'config/prod.json', root / 'codemagic.yaml']:
        assert pattern not in file.read_text(), f'Secret found in {file}'
assert 'requestTrackingAuthorization' in (root / 'ios/Runner/AppDelegate.swift').read_text()
assert 'verifyApplePurchase' in (root / 'lib/services/purchase_verification.dart').read_text()
print('Prospecto 1.6.0+52 native source preflight passed')
