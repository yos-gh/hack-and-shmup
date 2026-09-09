"""Negative checks for the artifact verifier, using only temporary fixtures."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from verify_build import verify


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='hack-shmup-build-')
        self.root = Path(self.temp.name).resolve()
        self.assertTrue(self.root.is_relative_to(Path(tempfile.gettempdir()).resolve()))
        (self.root / 'web').mkdir()
        names = ['index.html', 'game-v2.html', 'game-v2.js', 'game-v2.wasm', 'game-v2.pck']
        files = []
        with zipfile.ZipFile(self.root / 'web.zip', 'w') as archive:
            for name in names:
                value = name.encode()
                (self.root / 'web' / name).write_bytes(value)
                archive.writestr(name, value)
                files.append(dict(path=name, bytes=len(value), sha256=hashlib.sha256(value).hexdigest()))
        (self.root / 'source.zip').write_bytes(b'source fixture')
        self.manifest = dict(schema=1, tests=[dict(Passed=True, ExitCode=0)], files=files,
                             source_sha256=hashlib.sha256(b'source fixture').hexdigest(),
                             package_sha256=hashlib.sha256((self.root / 'web.zip').read_bytes()).hexdigest())
        self.write_manifest()

    def write_manifest(self):
        (self.root / 'manifest.json').write_text(json.dumps(self.manifest))

    def tearDown(self):
        self.temp.cleanup()

    def test_valid(self):
        self.assertEqual(verify(self.root), 5)

    def make_windows(self):
        names = ['hack-and-shmup.exe', 'hack-and-shmup.pck',
                 'libsentry.windows.release.x86_64.dll', 'crashpad_handler.exe', 'crashpad_wer.dll']
        (self.root / 'windows').mkdir()
        self.manifest['files'] = []
        with zipfile.ZipFile(self.root / 'windows.zip', 'w') as archive:
            for name in names:
                content = name.encode()
                (self.root / 'windows' / name).write_bytes(content)
                archive.writestr(name, content)
                self.manifest['files'].append(dict(path=name, bytes=len(content), sha256=hashlib.sha256(content).hexdigest()))
        self.manifest['package_sha256'] = hashlib.sha256((self.root / 'windows.zip').read_bytes()).hexdigest()
        self.manifest['target'] = 'Windows'
        self.manifest['startup_verified'] = True
        self.write_manifest()

    def test_windows(self):
        self.make_windows()
        self.assertEqual(verify(self.root), 5)

    def test_windows_requires_startup(self):
        self.make_windows()
        self.manifest['startup_verified'] = False
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'startup'):
            verify(self.root)

    def test_tampered_artifact(self):
        (self.root / 'web' / 'game-v2.pck').write_bytes(b'changed')
        with self.assertRaises(ValueError): verify(self.root)

    def test_extra_file(self):
        (self.root / 'web' / 'unexpected').write_text('extra')
        with self.assertRaises(ValueError): verify(self.root)

    def test_zip_content_not_just_package_hash(self):
        with zipfile.ZipFile(self.root / 'web.zip', 'w') as archive:
            for item in self.manifest['files']:
                archive.writestr(item['path'], b'wrong')
        self.manifest['package_sha256'] = hashlib.sha256((self.root / 'web.zip').read_bytes()).hexdigest()
        self.write_manifest()
        with self.assertRaises(ValueError): verify(self.root)

    def test_failed_regression(self):
        self.manifest['tests'][0]['Passed'] = False
        self.write_manifest()
        with self.assertRaises(ValueError): verify(self.root)

    def test_path_escape(self):
        self.manifest['files'][0]['path'] = '../source.zip'
        self.write_manifest()
        with self.assertRaises(ValueError): verify(self.root)


if __name__ == '__main__':
    unittest.main()
