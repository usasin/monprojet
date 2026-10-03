"""Fail before compilation if app identity or native configuration regresses."""
from pathlib import Path
import plistlib
import re

root = Path(__file__).resolve().parents[1]
info = plistlib.loads((root / 'ios/Runner/Info.plist').read_bytes())
firebase = plistlib.loads((root / 'ios/Runner/GoogleService-Info.plist').read_bytes())
project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
assert re.search(r'^version: 1\.6\.0\+51$', (root / 'pubspec.yaml').read_text(), re.M)
assert info['CFBundleDisplayName'] == 'Prospecto'
assert firebase['BUNDLE_ID'] == 'com.ainego.aiProspectGps'
assert firebase['PROJECT_ID'] == 'quiz-commercial'
assert info['GADApplicationIdentifier'] == 'ca-app-pub-1360261396564293~5907234032'
assert firebase['REVERSED_CLIENT_ID'] in info['CFBundleURLTypes'][0]['CFBundleURLSchemes']
assert project.count('GoogleService-Info.plist in Resources') >= 2
assert 'PRODUCT_BUNDLE_IDENTIFIER = com.ainego.aiProspectGps;' in project
assert len(info['UISupportedInterfaceOrientations~ipad']) == 4
assert info['ITSAppUsesNonExemptEncryption'] is False
assert 'NSPhotoLibraryUsageDescription' in info
assert 'NSCameraUsageDescription' in info
for pattern in ['BEGIN PRIVATE KEY', 'BEGIN RSA PRIVATE KEY', 'sk_live_', 'sk_test_']:
    for file in [root / 'config/prod.json', root / 'codemagic.yaml']:
        assert pattern not in file.read_text(), f'Secret found in {file}'
print('Prospecto 1.6.0+51 native source preflight passed')
