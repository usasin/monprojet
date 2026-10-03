import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import zipfile

ipas = list(Path('build/ios/ipa').glob('*.ipa'))
assert len(ipas) == 1, 'Expected one signed IPA'
with tempfile.TemporaryDirectory() as directory:
    with zipfile.ZipFile(ipas[0]) as archive:
        archive.extractall(directory)
    apps = list((Path(directory) / 'Payload').glob('*.app'))
    assert len(apps) == 1
    app = apps[0]
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    firebase = plistlib.loads((app / 'GoogleService-Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == 'com.ainego.aiProspectGps'
    assert info['CFBundleShortVersionString'] == '1.6.0'
    assert info['CFBundleVersion'] == os.environ['APP_BUILD_NUMBER']
    assert info['CFBundleDisplayName'] == 'Prospecto'
    assert info['GADApplicationIdentifier'] == 'ca-app-pub-1360261396564293~5907234032'
    assert int(info['DTSDKName'].removeprefix('iphoneos').split('.')[0]) >= 26
    assert firebase['BUNDLE_ID'] == info['CFBundleIdentifier']
    assert firebase['PROJECT_ID'] == 'quiz-commercial'
    profile = plistlib.loads(subprocess.check_output([
        'security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')
    ]))
    assert profile['Entitlements']['application-identifier'] == 'G6T4NT9XZ9.com.ainego.aiProspectGps'
    assert profile['Name'] == 'Prospecto App Store shared cert 2026'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)], check=True)
print('Signed Prospecto IPA verified: Firebase included, Apple SDK 26+, correct app/profile/version')
