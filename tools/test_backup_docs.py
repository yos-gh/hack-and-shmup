from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch
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

    def test_internal_backups_are_pruned_and_not_repackaged(self):
        with tempfile.TemporaryDirectory() as folder:
            docs = Path(folder) / 'docs'
            docs.mkdir()
            (docs / 'notes.md').write_text('keep', encoding='utf-8')
            first, count = create(docs, docs / 'backups')
            second, second_count = create(docs, docs / 'backups' / 'manual')
            self.assertNotEqual(first, second)
            self.assertEqual((count, second_count), (1, 1))
            self.assertEqual([row['path'] for row in verify(second)['files']], ['docs/notes.md'])
            for destination in [docs, docs / 'references' / 'backup']:
                with self.assertRaises(ValueError): create(docs, destination)

    def test_cli_defaults_to_backups_under_source(self):
        from backup_docs import main
        with tempfile.TemporaryDirectory() as folder:
            docs = Path(folder) / 'docs'
            docs.mkdir()
            (docs / 'notes.md').write_text('keep', encoding='utf-8')
            with patch('sys.argv', ['backup_docs.py', '--source', str(docs)]):
                main()
            archives = list((docs / 'backups').glob('*.zip'))
            self.assertEqual(len(archives), 1)
            self.assertEqual(len(verify(archives[0])['files']), 1)

if __name__ == '__main__': unittest.main()
