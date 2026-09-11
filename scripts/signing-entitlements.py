#!/usr/bin/env python3
"""Derive only the required Keychain entitlements from an authorized profile."""
import datetime
import fnmatch
import plistlib
import sys

profile_path, info_path, output_path = sys.argv[1:]
with open(profile_path, 'rb') as stream:
    profile = plistlib.load(stream)
with open(info_path, 'rb') as stream:
    bundle_id = plistlib.load(stream)['CFBundleIdentifier']
expiry = profile.get('ExpirationDate')
if not expiry or expiry <= datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
    sys.exit('The provisioning profile has expired or has no expiration date.')
allowed = profile.get('Entitlements', {})
prefixes = profile.get('ApplicationIdentifierPrefix', [])
if not prefixes:
    sys.exit('The provisioning profile has no application identifier prefix.')
app_id = prefixes[0].rstrip('.') + '.' + bundle_id
if not fnmatch.fnmatchcase(app_id, allowed.get('com.apple.application-identifier', '')):
    sys.exit('The provisioning profile does not authorize this bundle identifier.')
if not any(fnmatch.fnmatchcase(app_id, pattern) for pattern in allowed.get('keychain-access-groups', [])):
    sys.exit('The provisioning profile does not authorize the app Keychain access group.')
team = allowed.get('com.apple.developer.team-identifier')
if not team:
    sys.exit('The provisioning profile has no team identifier entitlement.')
with open(output_path, 'wb') as stream:
    plistlib.dump({
        'com.apple.application-identifier': app_id,
        'com.apple.developer.team-identifier': team,
        'keychain-access-groups': [app_id],
    }, stream)
