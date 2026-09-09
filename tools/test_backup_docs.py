from pathlib import Path
import tempfile
import unittest
import zipfile
from backup_docs import create, verify

class BackupTests(unittest.TestCase):
    def test_roundtrip_and_exclusions(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            docs = root / 'docs'
            (docs / 'references').mkdir(parents=True)
            (docs / 'builds').mkdir()
            (docs / 'README.md').write_text('制作資料', encoding='utf-8')
            (docs / 'references/art.bin').write_bytes(b'\x00\x01')
            (docs / 'builds/large.bin').write_bytes(b'excluded')
            archive, count = create(docs, root / 'backup')
            self.assertEqual(count, 2)
            self.assertEqual(len(verify(archive)['files']), 2)
            with zipfile.ZipFile(archive) as package:
                self.assertEqual(package.read('docs/README.md'), (docs / 'README.md').read_bytes())
            second, _ = create(docs, root / 'backup')
            self.assertNotEqual(archive, second)
            with self.assertRaises(ValueError): create(docs, docs / 'backup')
            with zipfile.ZipFile(archive, 'a') as package:
                package.writestr('unexpected', b'bad')
            with self.assertRaises(ValueError): verify(archive)

if __name__ == '__main__': unittest.main()
