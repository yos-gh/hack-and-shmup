"""Create and verify a non-overwriting backup of authored, Git-ignored docs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import uuid
import zipfile

EXCLUDED = {'builds', 'validation', 'ci', 'backups'}

def authored_files(source):
    # Prune generated trees before walking: never traverse old backups/builds.
    for folder, directories, files in os.walk(source, followlinks=False):
        folder = Path(folder)
        if folder == source:
            directories[:] = [name for name in directories if name not in EXCLUDED]
        for name in sorted(directories + files):
            file = folder / name
            if file.is_symlink() or source not in file.resolve().parents:
                raise ValueError('Linked paths are not supported: ' + str(file))
        for name in sorted(files):
            yield folder / name

def sha(data):
    return hashlib.sha256(data).hexdigest()

def verify(archive):
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate ZIP entries')
        manifest = json.loads(package.read('manifest.json'))
        if manifest.get('schema') != 1:
            raise ValueError('Unknown backup format')
        expected = {'manifest.json'}
        for item in manifest['files']:
            path = PurePosixPath(item['path'])
            if path.is_absolute() or '..' in path.parts or '\\' in item['path'] or ':' in item['path'] or not path.parts or path.parts[0] != 'docs':
                raise ValueError('Unsafe backup path')
            if item['path'] in expected:
                raise ValueError('Duplicate manifest entry')
            expected.add(item['path'])
            data = package.read(item['path'])
            if len(data) != item['bytes'] or sha(data) != item['sha256']:
                raise ValueError('Backup content mismatch: ' + item['path'])
        if set(names) != expected:
            raise ValueError('Unexpected archive contents')
        return manifest

def create(source, destination):
    source = Path(source).resolve()
    destination = Path(destination).resolve()
    if destination == source or (source in destination.parents and destination.relative_to(source).parts[0] != 'backups'):
        raise ValueError('Backup destination inside docs must be under docs/backups')
    if not source.is_dir():
        raise ValueError('Docs directory missing')
    destination.mkdir(parents=True, exist_ok=True)
    path = destination / ('docs-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8] + '.zip')
    rows = []
    with zipfile.ZipFile(path, 'x', compression=zipfile.ZIP_DEFLATED) as package:
        for file in sorted(authored_files(source)):
            relative = file.relative_to(source)
            data = file.read_bytes()
            name = 'docs/' + relative.as_posix()
            package.writestr(name, data)
            rows.append({'path': name, 'bytes': len(data), 'sha256': sha(data)})
        manifest = {'schema': 1, 'source': str(source), 'excluded_generated_directories': sorted(EXCLUDED), 'files': rows}
        package.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2))
    verify(path)
    path.with_suffix('.sha256').write_text(sha(path.read_bytes()) + '  ' + path.name + '\n', encoding='utf-8')
    return path, len(rows)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'docs')
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if args.verify:
        print(f'PASS: {len(verify(args.verify)["files"])} backup files verified')
    else:
        archive, count = create(args.source, args.output_dir or args.source / 'backups')
        print(f'PASS: {count} files backed up and verified: {archive}')

if __name__ == '__main__':
    main()
