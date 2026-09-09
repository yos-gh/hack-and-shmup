"""Exercise inventory drift and isolated regeneration using disposable copies."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class AssetAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='asset-audit-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'assets', self.root / 'assets')
        (self.root / 'tools').mkdir()
        (self.root / 'scripts').mkdir()
        for name in ['audit_assets.py', 'generate_audio.py', 'generate_warning.py']:
            shutil.copy2(ROOT / 'tools' / name, self.root / 'tools' / name)
        for shader in (ROOT / 'scripts').glob('*.gdshader'):
            shutil.copy2(shader, self.root / 'scripts' / shader.name)

    def run_audit(self, *args):
        return subprocess.run([sys.executable, str(self.root / 'tools/audit_assets.py'), *args],
                              capture_output=True, text=True)

    def test_regeneration_preserves_working_outputs(self):
        before = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in (self.root / 'assets/audio').glob('*.wav')}
        result = self.run_audit('--regenerate-audio')
        self.assertEqual(result.returncode, 0, result.stderr)
        after = {p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in (self.root / 'assets/audio').glob('*.wav')}
        self.assertEqual(before, after)

    def test_changed_generator_requires_review(self):
        with (self.root / 'tools/generate_audio.py').open('a') as source:
            source.write('\n# changed generator\n')
        self.assertNotEqual(self.run_audit().returncode, 0)

    def test_git_line_endings_do_not_change_inventory(self):
        for pattern in ['tools/*.py', 'assets/definitions/*.tres', 'scripts/*.gdshader']:
            for path in self.root.glob(pattern):
                path.write_bytes(path.read_bytes().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
        result = self.run_audit()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_new_or_missing_definition_requires_review(self):
        definition = self.root / 'assets/definitions/extra.tres'
        definition.write_text('[gd_resource format=3]\n', encoding='utf-8')
        self.assertNotEqual(self.run_audit().returncode, 0)
        definition.unlink()
        (self.root / 'assets/definitions/weapon_primary.tres').unlink()
        self.assertNotEqual(self.run_audit().returncode, 0)

if __name__ == '__main__':
    unittest.main()
