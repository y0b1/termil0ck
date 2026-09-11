import datetime
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class SigningEntitlementsTests(unittest.TestCase):
    def run_profile(self, mutate=lambda profile: None):
        profile = {
            'ExpirationDate': datetime.datetime(2099, 1, 1),
            'ApplicationIdentifierPrefix': ['TESTTEAM'],
            'Entitlements': {
                'com.apple.application-identifier': 'TESTTEAM.com.termilock.*',
                'com.apple.developer.team-identifier': 'TESTTEAM',
                'keychain-access-groups': ['TESTTEAM.*'],
            },
        }
        mutate(profile)
        with tempfile.TemporaryDirectory() as temporary:
            directory = pathlib.Path(temporary)
            source = directory / 'profile.plist'
            output = directory / 'entitlements.plist'
            source.write_bytes(plistlib.dumps(profile))
            result = subprocess.run([
                sys.executable, str(ROOT / 'scripts/signing-entitlements.py'),
                str(source), str(ROOT / 'Resources/Info.plist'), str(output),
            ], capture_output=True, text=True)
            entitlements = plistlib.loads(output.read_bytes()) if output.exists() else None
            return result, entitlements

    def test_authorized_profile_generates_only_required_entitlements(self):
        result, entitlements = self.run_profile()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(entitlements, {
            'com.apple.application-identifier': 'TESTTEAM.com.termilock.Termilock',
            'com.apple.developer.team-identifier': 'TESTTEAM',
            'keychain-access-groups': ['TESTTEAM.com.termilock.Termilock'],
        })

    def test_expired_profile_is_rejected(self):
        result, entitlements = self.run_profile(
            lambda p: p.update(ExpirationDate=datetime.datetime(2000, 1, 1)))
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(entitlements)

    def test_wrong_bundle_is_rejected(self):
        result, entitlements = self.run_profile(
            lambda p: p['Entitlements'].update({'com.apple.application-identifier': 'TESTTEAM.other.app'}))
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(entitlements)

    def test_missing_keychain_authorization_is_rejected(self):
        result, entitlements = self.run_profile(
            lambda p: p['Entitlements'].pop('keychain-access-groups'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(entitlements)

    def test_missing_team_is_rejected(self):
        result, entitlements = self.run_profile(
            lambda p: p['Entitlements'].pop('com.apple.developer.team-identifier'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(entitlements)


if __name__ == '__main__':
    unittest.main()
