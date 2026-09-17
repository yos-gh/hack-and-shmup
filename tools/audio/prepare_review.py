"""Prepare review media from REAPER renders. No synthesis occurs in this script."""
import csv
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/audio/sample/v02'
OUT = ROOT / 'docs/audio/review'


def ffmpeg(*arguments):
    result = subprocess.run(['ffmpeg', '-hide_banner', '-nostdin', '-y', *map(str, arguments)],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-2500:])
    return result.stderr


def measure(path):
    text = ffmpeg('-i', path, '-af', 'loudnorm=I=-17:TP=-2:LRA=11:print_format=json',
                  '-f', 'null', 'NUL')
    found = re.search(r'\{\s*"input_i".*?\}', text, re.S)
    if not found:
        raise RuntimeError('No loudness report for ' + str(path))
    data = json.loads(found.group())
    return {'lufs': float(data['input_i']), 'true_peak_db': float(data['input_tp'])}


def main():
    if 'COMPLETE' not in (SOURCE / 'render.txt').read_text(encoding='utf-8'):
        raise RuntimeError('REAPER batch did not complete')
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'source': str(SOURCE.relative_to(ROOT)), 'files': {}}
    raw = OUT / 'stage_01_unmastered.wav'
    ffmpeg('-i', SOURCE / 'black_circuit_source.wav', '-af',
           'atrim=start_sample=2304000:end_sample=4608000,asetpts=PTS-STARTPTS',
           '-ar', 48000, '-c:a', 'pcm_s24le', raw)
    levels = measure(raw)
    gain = min(-17 - levels['lufs'], -2 - levels['true_peak_db'])
    master = OUT / 'stage_01_master.wav'
    ffmpeg('-i', raw, '-af', f'volume={gain:.4f}dB', '-c:a', 'pcm_s24le', master)
    ffmpeg('-i', master, '-c:a', 'libvorbis', '-q:a', 7, OUT / 'stage_01.ogg')
    cues = list(csv.DictReader((SOURCE / 'cues.tsv').open(encoding='utf-8'), delimiter='\t'))
    target_peaks = {'shot': -9, 'scatter': -6, 'shock': -5, 'lance': -6,
                    'hit': -17, 'kill': -11, 'hunter_lock': -10, 'death': -7}
    for cue in cues:
        name = cue['name']
        start, length = float(cue['start']), float(cue['duration'])
        raw_cue = OUT / (name + '_master.wav')
        ffmpeg('-i', SOURCE / 'effects_source.wav', '-af',
               f'atrim=start={start}:duration={length},asetpts=PTS-STARTPTS,'
               f'afade=t=in:st=0:d=0.001,afade=t=out:st={length-.006}:d=0.006',
               '-c:a', 'pcm_s24le', raw_cue)
        cue_levels = measure(raw_cue)
        cue_gain = target_peaks[name] - cue_levels['true_peak_db']
        ffmpeg('-i', raw_cue, '-af', f'volume={cue_gain:.4f}dB', '-c:a', 'pcm_s16le',
               OUT / (name + '.wav'))
    # A labelled HTML list accompanies the isolated 2-second-per-effect audition.
    args = []
    filters = []
    for i, cue in enumerate(cues):
        args += ['-i', OUT / (cue['name'] + '.wav')]
        filters.append(f'[{i}:a]apad=whole_dur=2,atrim=duration=2[a{i}]')
    filters.append(''.join(f'[a{i}]' for i in range(len(cues))) +
                   f'concat=n={len(cues)}:v=0:a=1[out]')
    ffmpeg(*args, '-filter_complex', ';'.join(filters), '-map', '[out]',
           '-c:a', 'pcm_s16le', OUT / 'effects_audition.wav')
    for filename in ['stage_01.ogg', 'stage_01_master.wav', 'effects_audition.wav'] + [
            c['name'] + '.wav' for c in cues]:
        path = OUT / filename
        result = measure(path)
        if result['true_peak_db'] > -1:
            raise RuntimeError('Peak ceiling exceeded: ' + filename)
        result = {k: v if math.isfinite(v) else None for k, v in result.items()}
        result.update(bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        report['files'][filename] = result
    (OUT / 'analysis.json').write_text(json.dumps(report, indent=2, allow_nan=False), encoding='utf-8')
    print(json.dumps({k: {'lufs': v['lufs'], 'peak': v['true_peak_db']}
                      for k, v in report['files'].items()}))


if __name__ == '__main__':
    main()
