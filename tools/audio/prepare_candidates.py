"""Package REAPER candidate renders for listening, without touching game assets."""
from pathlib import Path
import hashlib
import html
import json
import math
import wave
import zipfile
import sys
from prepare_review import ffmpeg, measure

ROOT = Path(__file__).resolve().parents[2]
REVISION = sys.argv[1] if len(sys.argv)>1 else 'underground-v1'
assert REVISION in ['underground-v1','underground-v2','stage-v3','02-melody-v4','02-motion-v5','01-variants-v1','03-variants-v1']
BASE = ROOT / 'docs/audio/candidates' / REVISION
OUT = BASE / 'listening'


def main():
    catalog = json.loads((BASE / 'catalog.json').read_text())
    log = (BASE / 'render.txt').read_text()
    OUT.mkdir(exist_ok=True)
    for c in catalog:
        assert 'DONE '+c['id'] in log, c['id']+' did not finish'
        source = BASE / c['id'] / (c['id']+'_source.wav')
        start, end = round(c['seconds']*48000), round(c['seconds']*96000)
        raw = BASE / c['id'] / 'settled_loop.wav'
        ffmpeg('-i', source, '-af',
               f'atrim=start_sample={start}:end_sample={end},asetpts=PTS-STARTPTS',
               '-ar', 48000, '-c:a', 'pcm_s24le', raw)
        c['source_levels'] = measure(raw)
        assert all(math.isfinite(v) for v in c['source_levels'].values())
        c['frames'] = end-start
    targets = {}
    for role, target in [('stage', -19), ('title', -24)]:
        targets[role] = min([target]+[
            c['source_levels']['lufs']-2.5-c['source_levels']['true_peak_db']
            for c in catalog if c['role']==role])
    shared_gain = None
    if REVISION in ['02-melody-v4','01-variants-v1','03-variants-v1']:
        original=json.loads((ROOT/'docs/audio/candidates/stage-v3/listening/analysis.json').read_text())
        source_id={'01-variants-v1':'01_circuit_drive','03-variants-v1':'03_breaker_run'}.get(REVISION,'02_locked_current')
        original_gain=next(c['gain_db'] for c in original['tracks'] if c['id']==source_id)
        shared_gain=min([original_gain]+[-2.5-c['source_levels']['true_peak_db'] for c in catalog])
    for c in catalog:
        raw = BASE / c['id'] / 'settled_loop.wav'
        master = OUT / (c['id']+'_master.wav')
        gain = shared_gain if shared_gain is not None else targets[c['role']]-c['source_levels']['lufs']
        ffmpeg('-i', raw, '-af', f'volume={gain:.6f}dB', '-c:a', 'pcm_s24le', master)
        ffmpeg('-i', master, '-c:a', 'libmp3lame', '-b:a', '320k', OUT/(c['id']+'.mp3'))
        ffmpeg('-i', master, '-c:a', 'libvorbis', '-q:a', 7, OUT/(c['id']+'.ogg'))
        c['gain_db'] = gain
        c['files'] = {}
        for suffix in ['_master.wav', '.mp3', '.ogg']:
            path = OUT/(c['id']+suffix)
            levels = measure(path)
            assert levels['true_peak_db'] <= -1, (path, levels)
            c['files'][suffix] = dict(**levels, bytes=path.stat().st_size,
                                     sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        # Exact PCM length, no sample clipping, and seam compared with ordinary
        # sample transitions. A diagnostic, not a claim of subjective approval.
        pcm = BASE/c['id']/'boundary_check.wav'
        ffmpeg('-i', master, '-c:a', 'pcm_s16le', pcm)
        import array
        with wave.open(str(pcm), 'rb') as w:
            assert w.getnframes() == c['frames']
            assert w.getnchannels()==2 and w.getframerate()==48000
            samples = array.array('h', w.readframes(w.getnframes()))
        seam = max(abs(samples[k]-samples[-2+k]) for k in (0,1))/32768
        max_step = max(abs(samples[i]-samples[i-2]) for i in range(2,len(samples)))/32768
        c['boundary'] = dict(seam_step=seam, largest_internal_step=max_step)
        assert seam <= max_step+1/32768
        print(f"{c['id']}: {c['seconds']:.1f}s, {c['files']['.ogg']['lufs']:.2f} LUFS", flush=True)
    # Fifteen seconds from each track; only this comparison reel has fades.
    inputs, filters = [], []
    for i,c in enumerate(catalog):
        inputs += ['-i', OUT/(c['id']+'_master.wav')]
        start = (8 if REVISION in ['stage-v3','02-melody-v4','01-variants-v1','03-variants-v1'] else 24 if REVISION=='underground-v2' else 16)*240/c['bpm']
        filters.append(f'[{i}:a]atrim=start={start}:duration=15,asetpts=PTS-STARTPTS,'
                       f'afade=t=in:d=0.02,afade=t=out:st=14.8:d=0.2,'
                       f'apad=whole_dur=16,atrim=duration=16[a{i}]')
        c['sampler_start'] = i*16
    filters.append(''.join(f'[a{i}]' for i in range(len(catalog)))+
                   f'concat=n={len(catalog)}:v=0:a=1[out]')
    ffmpeg(*inputs, '-filter_complex', ';'.join(filters), '-map', '[out]',
           '-c:a', 'libmp3lame', '-b:a', '320k', OUT/'comparison.mp3')
    report = dict(target_lufs=targets if shared_gain is None else None, shared_gain_db=shared_gain, tracks=catalog,
                  validation='File decoding, frame count, loudness, true peak and boundary diagnostics. No game integration or subjective listening approval.')
    (OUT/'analysis.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    cards=[]
    for c in catalog:
        sec=round(c['seconds'])
        cards.append(f'''<article><div class="meta">{c['id'].split('_')[0].upper()} · {c.get('intended_role',c['role']).upper()} · {c['bpm']} BPM · {sec//60}:{sec%60:02}</div>
<h2>{html.escape(c['title'])}</h2><p>{html.escape(c['description'])}</p>
<audio controls preload="none" src="{c['id']}.ogg"></audio>
<div class="links"><label><input type="checkbox" onchange="this.closest('article').querySelector('audio').loop=this.checked"> Loop</label>
<a href="{c['id']}.mp3" download>MP3</a> <a href="{c['id']}.ogg" download>Ogg loop</a></div></article>''')
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Underground / Soundtrack candidates</title><style>
*{box-sizing:border-box}body{margin:0;background:#101316;color:#e0e5e2;font:16px/1.5 system-ui,sans-serif}main{max-width:1000px;margin:auto;padding:48px 24px}header{margin-bottom:34px}h1{font-size:42px;letter-spacing:-1px;margin:10px 0}h2{font-size:23px;margin:8px 0}p{color:#a9b2b1}.meta{color:#92ceb7;font-size:12px;letter-spacing:1.2px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}article{border:1px solid #303a3a;border-radius:12px;background:#191e21;padding:22px}audio{width:100%;margin:12px 0}.links{display:flex;gap:18px;font-size:13px}a{color:#a8d8e4}label{cursor:pointer}header audio{max-width:600px;display:block}</style>
<main><header><div class="meta">SOUNDTRACK SELECTION / 01</div><h1>Underground transmissions</h1><p>Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.</p><p>Start with the comparison reel: 15 seconds per track, in the order below. Full tracks repeat without a closing fade. Choose the tracks you want to take further.</p><audio controls preload="none" src="comparison.mp3"></audio></header><div class="grid">'''+''.join(cards)+'''</div></main><script>
document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>{document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})}));</script></html>'''
    if REVISION=='underground-v2':
        page=page.replace('SELECTION / 01','SELECTION / 02').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'Three revised stage tracks. Three boss studies. One revised title theme. Familiar dark grooves with veiled strings and a restrained melodic thread.')
    if REVISION=='stage-v3':
        page=page.replace('SELECTION / 01','SELECTION / 03').replace('Underground transmissions','Circuit studies').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'Three stage studies returning to the original BLACK CIRCUIT drive. Compact melodies, stable pitch and three distinct drum/bass palettes.')
    if REVISION=='02-melody-v4':
        page=page.replace('SELECTION / 01','SELECTION / 04').replace('Underground transmissions','One groove, four hooks').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'Four melody studies for LOCKED CURRENT. The same opening and backing, four memorable minor-key themes. Each audition lasts 47 seconds; melody enters after 12 seconds.')
    if REVISION=='02-motion-v5':
        page=page.replace('SELECTION / 01','SELECTION / 05').replace('Underground transmissions','Locked Current / Motion').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'One full-length stage-02 study. Clipped hooks, interlocking answers and short chord layers over the original bass and drums.')
    if REVISION=='01-variants-v1':
        page=page.replace('SELECTION / 01','STAGE 01 / THREE STUDIES').replace('Underground transmissions','Circuit Drive / Variations').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'Three 48-second stage-01 studies: a sharp riff, a moving game melody, and layered rave chords. The same opening and drum/bass foundation; melody enters at 12 seconds.')
    if REVISION=='03-variants-v1':
        page=page.replace('SELECTION / 01','STAGE 03 / THREE STUDIES').replace('Underground transmissions','Breaker Run / Fragments').replace('Eight stage tracks. Two quiet title themes. Original chip sequences, deeper bass and darker spaces.',
             'Three short stage-03 studies. Low clipped riffs, gated arpeggios, or metallic retriggers over the same breakbeat foundation. No singing lead.')
    (OUT/'index.html').write_text(page, encoding='utf-8')
    (OUT/'playlist.m3u8').write_text('#EXTM3U\n'+''.join(
        f"#EXTINF:{c['seconds']:.0f},{c['title']}\n{c['id']}.mp3\n" for c in catalog),encoding='utf-8')
    with zipfile.ZipFile(BASE/'underground-listening.zip','w',zipfile.ZIP_DEFLATED) as z:
        for path in OUT.iterdir():
            if path.suffix in ['.mp3','.ogg','.html','.m3u8','.json']:
                z.write(path, path.name)
    (BASE/'README.md').write_text('''# Underground candidate set

Audition only. The user approved the representative SFX direction and requested
more underground BGM candidates before selecting any for the game.

Open `listening/index.html` or `listening/playlist.m3u8`. The comparison reel uses
15-second excerpts with a one-second gap, in catalog order.
Full WAV/Ogg tracks are settled middle passes from three-cycle REAPER renders,
without an end fade. MP3 files are convenient auditions; use WAV/Ogg for looping.
Stage tracks share an integrated loudness target; title tracks share a quieter one.
See `listening/analysis.json` for measured values and file hashes.

Each source folder preserves the score, MIDI, editable REAPER project and
48 kHz / 24-bit three-pass render. The projects require Magical 8bit Plug 2,
REAPER stock ReaEQ/ReaDelay/ReaComp and stock JS Saturation [LOSER].
Tools under `tools/audio` reproduce scoring, rendering and packaging.
Nothing in shipped game assets or playback logic is changed by this set.
Musical selection and in-game loop/mix verification remain pending.
''',encoding='utf-8')
    if REVISION=='stage-v3':
        (BASE/'README.md').write_text('''# Stage studies / round three

Only stages 01–03 were remade. The first stage_01.ogg / BLACK CIRCUIT sample
is the rhythmic and mixing reference. The original high, jaunty hook is replaced
with compact lower-register melodies. There are no long string/pad layers,
chorus, unison detuning or melodic/bass pitch envelopes. Percussion retains
its transient pitch envelopes. ReaDelay is very quiet on the single lead voice.

01: round triangle kick, 25-percent pulse bass, medium noise snare.
02: lower, longer kick, broad 50-percent square bass, short clap-like noise.
    A stable two-bar bass figure varies only at phrase endings.
03: breakbeats, short higher kick, crisp snare, driven triangle bass.

All three have 80 bars, approximately two-minute full loops. Audition only.
The comparison reel plays 01, 02, 03 for 15 seconds each with one-second gaps.
WAV masters are 48 kHz / 24-bit settled middle passes of three REAPER cycles;
MP3/Ogg auditions share a loudness target. Full loops have no closing fade.
See listening/analysis.json for frame counts, boundary diagnostics and peaks.
These checks do not constitute musical approval or in-game playback validation.

Editable RPP projects, MIDI, scores and source renders are in each song folder.
Reproduce with stage_round3.py, reaper_round3.lua (select one ID at a time),
then prepare_candidates.py stage-v3. No previous title/boss/SE or game files
are modified by this round. No browser playback check was attempted.
''',encoding='utf-8')
    if REVISION=='02-melody-v4':
        (BASE/'README.md').write_text('''# LOCKED CURRENT / four melody studies

Four 46.8-second, 32-bar auditions at 164 BPM. Only stage 02 is developed.
The first 11.7 seconds retain its opening. Then an eight-bar theme, an answering
cadence and a restatement follow. These are short studies, not final full tracks.

A / REDLINE OATH: heroic minor-key call and leading-tone return.
B / NEON PURSUIT: syncopated repeated hook and clipped descending answers.
C / LAST RESOLVE: dramatic rising arc with a firm minor-key answer.
D / NIGHT SIGNAL: tense Phrygian hook and narrow semitone turns.

All four share identical accompaniment notes/patches and the same lead sound.
No lead detuning or pitch envelope. The melodic range stays within C4–Eb5.
One common output gain preserves backing level across variants; small integrated
loudness differences are the result of different melodies. The comparison reel
plays A, B, C, D, starting at each melody entrance for 15 seconds plus a gap.

Full auditions are MP3/Ogg; WAV masters are 48 kHz / 24-bit settled middle passes
from three REAPER cycles. Source projects, MIDI and scores remain in each folder.
Measured peaks, frame counts and boundary diagnostics are in analysis.json.
No game integration or subjective approval is implied by those checks.
Earlier music, title, bosses, SE and game files are untouched.

Reproduce: melody_round4.py, reaper_melody4.lua, then
prepare_candidates.py 02-melody-v4. Requires the same REAPER/Magical 8bit setup.
''',encoding='utf-8')
    if REVISION=='02-motion-v5':
        (BASE/'README.md').write_text('''# LOCKED CURRENT / Motion V5

One full-length stage-02 study, 117.1 seconds at 164 BPM.
The original bass and drums are retained. The opening eight bars remain;
then a clipped four-bar hook, answering figures and short chord layers enter.
Lead notes last at most 0.4 beats (about 146 ms). No sustained solo anthem,
detune, chorus or melody pitch envelopes. Voice count is not restricted to NES
hardware: 15 tracks include a separate counterline, chord flashes and sparse
octave punctuation. Not all parts play continuously.

Approximate structure: 0:00 original opening; 0:12 main hook; 0:35 answer;
0:47 percussion/bass-led relief; 0:59 hook return; 1:10 second answer;
1:22 layered return; 1:34 full hook. The settled full loop has no ending fade.

MP3 and Ogg are auditions. WAV master: 48 kHz / 24-bit. REAPER source, MIDI,
score data and three-cycle render remain in the source folder. File decode,
exact frames, boundary-step diagnostics and true peaks are recorded in analysis.
Musical approval and game playback tests are separate and remain pending.
Earlier material and game assets are unchanged. No publication or game integration.
Reproduce: locked_current_v5.py, reaper_motion5.lua,
then prepare_candidates.py 02-motion-v5. Same REAPER/Magical 8bit setup.
''',encoding='utf-8')
    if REVISION=='01-variants-v1':
        (BASE/'README.md').write_text('''# CIRCUIT DRIVE / Three stage-01 studies

Three 48-second auditions at 160 BPM. A / RAZOR: tight repeating pulse riff.
B / OVERRUN: articulated rising minor-key game melody. C / GRIDLOCK: layered
rave chords and a tense semitone hook. All retain the first 32 bars of stage-01
drums/bass; the melody enters at 12 seconds. The middle phrase uses call/response,
and the return adds sparse octave reinforcement. No detuning or sustained pads.

One common output gain preserves backing level across variants. The comparison
reel plays A/B/C, 15 seconds each plus a gap, starting at the melody entrance.
These are selection studies, not final full-length stage loops. WAV masters are
48 kHz / 24-bit settled middle passes from three REAPER cycles. MP3/Ogg auditions,
source projects, MIDI and scores are preserved. Analysis records mechanical file
checks, not musical approval or in-game playback verification.

Stage 02 is left at MOTION V5 with no further revisions. No game integration.
Delivery is LOCAL ONLY; Google Drive upload requires an explicit user request.
Reproduce: circuit_variants.py, reaper_circuit_variants.lua,
then prepare_candidates.py 01-variants-v1.
''',encoding='utf-8')
    if REVISION=='03-variants-v1':
        (BASE/'README.md').write_text('''# BREAKER RUN / Three stage-03 studies

Three 46.3-second auditions at 166 BPM. A / CUTBACK: low clipped riff with
short answering ticks. B / PHASE STEPS: gated minor arpeggio cells. C / SCRAMBLE:
metallic pulse fragments and retriggers. No singing lead or sustained upper notes;
upper note gates are at most 0.17 beats (about 61 ms). No pitch bends/detuning.
The original breakbeat drum/bass data is preserved. Four bars introduce the groove,
then cells enter sparsely; bar eight establishes the full texture. The middle
thins the upper voices before their return. A common gain preserves backing level.

Comparison reel: A/B/C, 15 seconds each with one-second gaps. Full files are
short selection studies, not final two-minute tracks. WAV masters: 48 kHz/24-bit,
settled middle passes of three REAPER cycles. MP3/Ogg and editable projects/MIDI
are preserved. Mechanical audio checks are separate from musical approval and
game playback validation. Stage 01 C / GRIDLOCK is the preferred candidate;
02 remains MOTION V5. No game integration. LOCAL DELIVERY ONLY, no Drive upload.

Reproduce: breaker_variants.py, reaper_breaker_variants.lua,
then prepare_candidates.py 03-variants-v1.
''',encoding='utf-8')
    with zipfile.ZipFile(BASE/'underground-listening.zip','a',zipfile.ZIP_DEFLATED) as z:
        z.write(BASE/'README.md','README.md')
    print('Listening package ready',flush=True)


if __name__=='__main__':
    main()
