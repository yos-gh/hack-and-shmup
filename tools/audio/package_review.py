"""Archive editable review sources, excluding bulky capture intermediates."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DESTINATION = ROOT / 'docs/audio/sound_review_sources.zip'


def main():
    paths = list((ROOT / 'tools/audio').glob('*.py'))
    for extension in ['*.lua', '*.gd', '*.ps1', '*.md']:
        paths.extend((ROOT / 'tools/audio').glob(extension))
    paths += [ROOT / 'docs/SOUND_DIRECTION.md']
    paths += [ROOT / 'docs/audio/sample' / name for name in
              ['score.json', 'score.lua', 'black_circuit.mid']]
    for extension in ['*.rpp', '*.wav', '*.txt', '*.tsv']:
        paths.extend((ROOT / 'docs/audio/sample/v02').glob(extension))
    paths += [ROOT / 'docs/audio/review' / name for name in
              ['stage_01_master.wav', 'stage_01.ogg', 'effects_audition.wav',
               'analysis.json', 'verification.json', 'combat.mp4']]
    for cue in ['shot', 'scatter', 'shock', 'lance', 'hit', 'kill', 'hunter_lock', 'death']:
        paths.append(ROOT / 'docs/audio/review' / (cue + '.wav'))
        paths.append(ROOT / 'docs/audio/review' / (cue + '_master.wav'))
    manifest = {}
    with zipfile.ZipFile(DESTINATION, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(set(paths)):
            name = path.relative_to(ROOT).as_posix()
            archive.write(path, name)
            manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        archive.writestr('SOURCE_MANIFEST.json', json.dumps(manifest, indent=2))
    with zipfile.ZipFile(DESTINATION) as archive:
        assert archive.testzip() is None
    print(f'PASS: {len(manifest)} source/review files archived ({DESTINATION.stat().st_size:,} bytes)')


if __name__ == '__main__':
    main()
