"""Reuse the installed shared certificate and one app-specific Apple profile."""
import base64
import datetime as dt
import hashlib
import json
import os
import pathlib
import plistlib
import re
import subprocess

BUNDLE = "com.ainego.aiProspectGps"
TEAM = "G6T4NT9XZ9"
PROFILE_NAME = "Prospecto App Store shared cert 2026"

def apple(*args):
    result = subprocess.run(
        ["app-store-connect", "--json", "--log-stream", "stderr", *args],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)

def single(values, label):
    if len(values) != 1:
        raise RuntimeError(f"Expected exactly one {label}; got {len(values)}")
    return values[0]

identities = subprocess.check_output(
    ["security", "find-identity", "-v", "-p", "codesigning"], text=True
)
fingerprints = set(re.findall(r"\b[0-9A-F]{40}\b", identities))
certificates = apple("certificates", "list", "--type", "DISTRIBUTION")
matching = [c for c in certificates if hashlib.sha1(
    base64.b64decode(c["attributes"]["certificateContent"])
).hexdigest().upper() in fingerprints]
certificate = single(matching, "installed Apple Distribution certificate")
if not certificate["attributes"]["expirationDate"].startswith("2027-09-13"):
    raise RuntimeError("The installed certificate is not the permanent shared certificate")
certificate_der = base64.b64decode(certificate["attributes"]["certificateContent"])
bundle = single([b for b in apple("bundle-ids", "list", "--bundle-id-identifier", BUNDLE)
                 if b["attributes"]["identifier"] == BUNDLE], "Prospecto Bundle ID")
app = single([a for a in apple("apps", "list", "--bundle-id-identifier", BUNDLE)
              if a["attributes"]["bundleId"] == BUNDLE], "Prospecto App Store app")

profiles = apple("profiles", "list", "--type", "IOS_APP_STORE", "--name", PROFILE_NAME)
valid = [p for p in profiles if p["attributes"]["name"] == PROFILE_NAME
         and p["attributes"]["profileState"] == "ACTIVE"]
if valid:
    profile = single(valid, "active permanent Prospecto profile")
else:
    profile = apple("profiles", "create", bundle["id"], "--certificate-ids",
                    certificate["id"], "--type", "IOS_APP_STORE", "--name", PROFILE_NAME)

profile_bytes = base64.b64decode(profile["attributes"]["profileContent"])
decoded = subprocess.run(["security", "cms", "-D"], input=profile_bytes,
                         capture_output=True, check=True).stdout
settings = plistlib.loads(decoded)
assert settings["TeamIdentifier"] == [TEAM]
assert settings["Entitlements"]["application-identifier"] == f"{TEAM}.{BUNDLE}"
assert certificate_der in settings["DeveloperCertificates"]
assert settings["ExpirationDate"] > dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
assert not settings["Entitlements"].get("get-task-allow", False)
assert not settings.get("ProvisionedDevices")
destination = pathlib.Path.home() / "Library/MobileDevice/Provisioning Profiles"
destination.mkdir(parents=True, exist_ok=True)
(destination / f'{settings["UUID"]}.mobileprovision').write_bytes(profile_bytes)

latest = subprocess.check_output([
    "app-store-connect", "get-latest-build-number", app["id"],
    "--platform", "IOS", "--all-versions"
], text=True).strip()
next_build = max(51, int(latest) + 1)
with open(os.environ["CM_ENV"], "a") as env:
    env.write(f'APP_STORE_APPLE_ID={app["id"]}\nAPP_BUILD_NUMBER={next_build}\n')
print(f'Prospecto Apple ID: {app["id"]}; version 1.6.0; build {next_build}')
print(f'Profile: {PROFILE_NAME}; shared certificate reused; no certificate created')
