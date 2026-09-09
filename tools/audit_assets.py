"""Inventory project-authored assets and verify audio regeneration in isolation."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'assets/catalog.json'

def content(path):
    data = path.read_bytes()
    return data.replace(b'\r\n', b'\n') if path.suffix in {'.py', '.tres', '.gdshader', '.js'} else data

def digest(path):
    return hashlib.sha256(content(path)).hexdigest()

def inventory():
    rows = []
    paths = sorted((ROOT / 'assets/audio').glob('*.wav'))
    paths += sorted((ROOT / 'assets/definitions').glob('*.tres'))
    paths += sorted((ROOT / 'scripts').glob('*.gdshader'))
    for path in paths:
        relative = path.relative_to(ROOT).as_posix()
        row = {'path': relative, 'bytes': len(content(path)), 'sha256': digest(path)}
        if path.suffix == '.wav':
            source = 'tools/generate_warning.py' if path.stem == 'warning' else 'tools/generate_audio.py'
            row.update(kind='generated_audio', source=source, source_sha256=digest(ROOT / source))
            with wave.open(str(path), 'rb') as audio:
                row.update(channels=audio.getnchannels(), sample_bytes=audio.getsampwidth(),
                           sample_rate=audio.getframerate(), frames=audio.getnframes())
        else:
            row.update(kind='authored_definition' if path.suffix == '.tres' else 'authored_shader', source=relative)
        rows.append(row)
    dependencies = []
    for path in sorted([* (ROOT / 'addons/sentry/bin/windows/x86_64').glob('*'), * (ROOT / 'addons/sentry/bin/web').glob('*')]):
        if path.is_file() and path.suffix in {'.dll', '.exe', '.wasm'}:
            dependencies.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
                                 'sha256': digest(path), 'notice': 'addons/sentry/LICENSE.md'})
    bundle = ROOT / 'addons/sentry/web/sentry-bundle.js'
    if bundle.is_file():
        dependencies.append({'path': bundle.relative_to(ROOT).as_posix(), 'bytes': len(content(bundle)),
                             'sha256': digest(bundle), 'notice': 'addons/sentry/LICENSE.md'})
    return {'schema': 1, 'scope': 'assets/audio/*.wav, assets/definitions/*.tres, scripts/*.gdshader',
            'rights_status': 'Project-local source identified; this inventory does not assign a license or establish ownership.',
            'dependency_version_policy': 'Exact bundled bytes are pinned below. Upstream SDK release and transitive notice completeness are not established by these hashes.',
            'dependencies': dependencies,
            'assets': rows}

def verify_audio():
    with tempfile.TemporaryDirectory(prefix='shmup-assets-') as folder:
        workspace = Path(folder)
        (workspace / 'tools').mkdir()
        output = workspace / 'assets/audio'
        output.mkdir(parents=True)
        for name in ['generate_audio.py', 'generate_warning.py']:
            shutil.copy2(ROOT / 'tools' / name, workspace / 'tools' / name)
            subprocess.run([sys.executable, str(workspace / 'tools' / name)], check=True,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        expected = {p.name: digest(p) for p in (ROOT / 'assets/audio').glob('*.wav')}
        generated = {p.name: digest(p) for p in output.glob('*.wav')}
        if expected != generated:
            changed = sorted(name for name in expected.keys() | generated.keys()
                             if expected.get(name) != generated.get(name))
            raise ValueError('Audio regeneration differs: ' + ', '.join(changed))
        return len(expected)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true', help='explicitly refresh catalog after an intentional asset change')
    parser.add_argument('--regenerate-audio', action='store_true', help='compare isolated generated WAVs with committed outputs')
    args = parser.parse_args()
    current = inventory()
    if args.regenerate_audio:
        print(f'PASS: {verify_audio()} audio files regenerate byte-for-byte')
    if args.write:
        CATALOG.write_text(json.dumps(current, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    elif json.loads(CATALOG.read_text(encoding='utf-8')) != current:
        raise ValueError('Asset inventory drift: review changes, then explicitly refresh with --write')
    print(f'PASS: {len(current["assets"])} project assets match catalog')

if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, wave.Error) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)


