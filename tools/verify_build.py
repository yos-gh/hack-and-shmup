"""Verify a local build manifest, loose artifacts, and ZIP without extracting it."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(directory):
    root = Path(directory).resolve()
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8-sig'))
    if manifest.get('schema') != 1:
        raise ValueError('Unsupported manifest schema')
    tests = manifest.get('tests', [])
    if not tests or any(t.get('Passed') is not True or t.get('ExitCode') != 0 for t in tests):
        raise ValueError('Build does not contain a passing regression report')
    for name, field in [('source.zip', 'source_sha256'), ('web.zip', 'package_sha256')]:
        if digest((root / name).read_bytes()) != manifest[field]:
            raise ValueError(f'Hash mismatch: {name}')
    artifact_root = root / 'web'
    expected = {}
    for item in manifest['files']:
        name = item['path']
        path = (artifact_root / name).resolve()
        if not path.is_relative_to(artifact_root) or name in expected or '\\' in name:
            raise ValueError(f'Invalid or duplicate artifact path: {name}')
        content = path.read_bytes()
        if len(content) != item['bytes'] or digest(content) != item['sha256']:
            raise ValueError(f'Artifact mismatch: {name}')
        expected[name] = item
    required = {'index.html', 'game-v2.html', 'game-v2.js', 'game-v2.wasm', 'game-v2.pck'}
    if not required <= expected.keys():
        raise ValueError('Missing required Web artifact')
    actual = {p.relative_to(artifact_root).as_posix() for p in artifact_root.rglob('*') if p.is_file()}
    if actual != expected.keys():
        raise ValueError('Unexpected loose artifact files')
    with zipfile.ZipFile(root / 'web.zip') as archive:
        names = [i.filename for i in archive.infolist() if not i.is_dir()]
        if len(names) != len(set(names)) or set(names) != expected.keys():
            raise ValueError('ZIP file list does not match manifest')
        for name in names:
            content = archive.read(name)
            if len(content) != expected[name]['bytes'] or digest(content) != expected[name]['sha256']:
                raise ValueError(f'ZIP content mismatch: {name}')
    return len(expected)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    try:
        count = verify(args.directory)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f'FAIL: {error}\n')
    print(f'PASS: {count} artifacts and ZIP contents match manifest')
