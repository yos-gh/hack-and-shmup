"""Create an old/new listening reel and finish the second-round portable package."""
from pathlib import Path
import json
import re
import zipfile
from prepare_review import ffmpeg, measure

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/audio/candidates'
OUT=BASE/'underground-v2/listening'


def main():
    old=json.loads((BASE/'underground-v1/listening/analysis.json').read_text())
    new=json.loads((OUT/'analysis.json').read_text())
    old_by_id={c['id']:c for c in old['tracks']}
    inputs=[];filters=[];timeline=[]
    for c in [c for c in new['tracks'] if c['id'].endswith('_v2')]:
        original=old_by_id[c['id'][:-3]]
        levels=[original['files']['_master.wav'],c['files']['_master.wav']]
        target=min([-24.5 if c['role']=='title' else -23.5]+
                   [v['lufs']-2.5-v['true_peak_db'] for v in levels])
        for take,entry,revision,lev in [('A',original,'underground-v1',levels[0]),
                                       ('B',c,'underground-v2',levels[1])]:
            i=len(inputs)//2
            inputs+=['-i',BASE/revision/'listening'/(entry['id']+'_master.wav')]
            start=24*240/entry['bpm']
            filters.append(f'[{i}:a]atrim=start={start}:duration=12,asetpts=PTS-STARTPTS,'
                           f'volume={target-lev["lufs"]:.6f}dB,afade=t=in:d=0.015,'
                           f'afade=t=out:st=11.8:d=0.2,apad=whole_dur=13,atrim=duration=13[a{i}]')
            timeline.append(dict(at_seconds=i*13,track=entry['id'],take=take,target_lufs=target))
    filters.append(''.join(f'[a{i}]' for i in range(len(timeline)))+
                   f'concat=n={len(timeline)}:v=0:a=1[out]')
    ffmpeg(*inputs,'-filter_complex',';'.join(filters),'-map','[out]',
           '-c:a','libmp3lame','-b:a','320k',OUT/'old_new.mp3')
    for name in ['old_new.mp3','comparison.mp3']:
        lev=measure(OUT/name)
        assert lev['true_peak_db']<=-1,lev
    (OUT/'comparison_timeline.json').write_text(json.dumps(timeline,indent=2),encoding='utf-8')
    page=(OUT/'index.html').read_text(encoding='utf-8')
    page=page.replace('</header>', '<p>Old / new comparison: 01, 02, 03, T2. '
        'Each pair plays the original (12 seconds), then the revision (12 seconds), with short gaps. '
        'Levels are matched within each pair.</p><audio controls preload="none" src="old_new.mp3"></audio></header>')
    (OUT/'index.html').write_text(page,encoding='utf-8')
    for link in re.findall(r'(?:href|src)="([^"]+)"',page):
        assert (OUT/link).is_file(),link
    readme='''# Underground / second listening round

Seven audition-only tracks; no game integration.
01 / SUBLEVEL 09 V2: retained warehouse groove, veiled strings and sparse melody.
02 / ACID CRAWL V2: five bass phrases, 8/16-bar changes, sustained minor colors.
03 / PIRATE SIGNAL V2: retained breakbeats, drifting melody and chip-string chords.
B1 / SIEGE PRESSURE: crushing accents and slow warning motif, for SIEGE ARRAY.
B2 / VECTOR PURSUIT: displaced beats and stalking bass, for VECTOR HUNTER.
B3 / HALO RITUAL: revolving triplet figures and suspended strings, for HALO ENGINE.
T2 / BELOW THE GRID V2: original quiet pulse, faint sustained harmony.

Open listening/index.html or playlist.m3u8. The 7-track comparison reel plays
15 seconds per track plus a one-second gap, in the order above.
old_new.mp3 compares original then revised 01, 02, 03, T2 (12 seconds each,
one-second gaps). Timings are in comparison_timeline.json.

All full loops have no closing fade. They are settled middle passes of three
REAPER cycles. WAV masters: 48 kHz / 24-bit. Auditions: MP3 and Ogg Vorbis.
Source RPP, MIDI, scores and three-pass renders remain in each source folder.
The previous round is preserved unchanged.

File decoding, exact frame count, boundary-step diagnostics and encoded true
peak checks passed. These are mechanical checks, not listening approval or
proof of in-game loop behavior. In-game testing remains deferred until selection.
The browser playback issue from round one is unresolved; no new browser playback
claim is made. Open the MP3s in a local audio player if necessary.

Reproduction: revision_scores.py, reaper_revision.lua (one selected catalog ID
at a time), prepare_candidates.py underground-v2, then compare_revisions.py.
The synth is Magical 8bit Plug 2 with REAPER stock effects, as in round one.
'''
    (BASE/'underground-v2/README.md').write_text(readme,encoding='utf-8')
    with zipfile.ZipFile(BASE/'underground-v2/underground-listening.zip','w',zipfile.ZIP_DEFLATED) as z:
        for p in OUT.iterdir():
            if p.suffix in ['.html','.mp3','.ogg','.m3u8','.json']:z.write(p,p.name)
        z.writestr('README.md',readme.replace('listening/index.html','index.html'))
    print(json.dumps(dict(tracks=len(new['tracks']),
          peak=max(v['true_peak_db'] for c in new['tracks'] for v in c['files'].values()),
          archive_bytes=(BASE/'underground-v2/underground-listening.zip').stat().st_size)))


if __name__=='__main__':main()
