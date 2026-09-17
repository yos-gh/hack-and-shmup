"""Preserve selected editable sources, install approved SFX, list disposable media."""
import hashlib,json,re,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/audio'
SELECTED=BASE/'selected'
EFFECTS=['shot','scatter','shock','lance','hit','kill','hunter_lock','death']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(a,b):
    b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)
    assert digest(a)==digest(b)
def main():
    manifest=[]
    picks=[('title','underground-v2','t2_below_the_grid_v2'),
           ('stage_01','01-variants-v1','c_gridlock'),
           ('stage_02','02-motion-v5','02_locked_current_v5'),
           ('stage_03','03-variants-v1','b_phase_steps')]
    for label,revision,id in picks:
        source=BASE/'candidates'/revision/id;out=SELECTED/label
        for p in source.iterdir():
            if p.suffix in ['.rpp','.mid','.json','.lua'] or p.name==id+'_source.wav':copy(p,out/p.name)
        for ext in ['_master.wav','.mp3']:
            copy(source.parent/'listening'/(id+ext),out/(id+ext))
        manifest.append(dict(selection=label,id=id,source=str(source.relative_to(ROOT))))
    ref=SELECTED/'reference_original_stage01'
    for p in (BASE/'sample/v02').glob('black_circuit_source.*'):copy(p,ref/p.name)
    for name in ['score.json','score.lua','black_circuit.mid']:copy(BASE/'sample'/name,ref/name)
    for name in ['stage_01_master.wav','stage_01.ogg']:copy(BASE/'review'/name,ref/name)
    se=BASE/'production_se'
    for name in ['effects_source.rpp','effects_source.wav','cues.tsv']:copy(BASE/'sample/v02'/name,se/name)
    sources={}
    for name in EFFECTS:
        p=ROOT/'assets/audio'/(name+'.wav');copy(BASE/'review'/(name+'.wav'),p)
        sources[p.name]=dict(sha256=digest(p),source='tools/audio/reaper_sample.lua',
             project='docs/audio/production_se/effects_source.rpp',
             method='REAPER Magical 8bit Plug 2 and stock effects; 48 kHz stereo 16-bit PCM')
    (ROOT/'assets/audio/production_sources.json').write_text(json.dumps(sources,indent=2)+'\n',encoding='utf-8')
    # Projects are entirely embedded MIDI/VST state. Do not remove external media.
    for p in list(SELECTED.rglob('*.rpp'))+list(se.glob('*.rpp')):
        text=p.read_text(encoding='utf-8')
        assert '<SOURCE WAVE' not in text and '<SOURCE MP3' not in text
        text=re.sub(r'(?m)^  RENDER_FILE .*$',lambda m:'  RENDER_FILE "'+str(p.with_suffix('.wav')).replace('\\','/')+'"',text)
        p.write_text(text,encoding='utf-8')
    (SELECTED/'selection.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (SELECTED/'README.md').write_text('''# Current BGM selection / editable handoff

- title: BELOW THE GRID V2
- stage_01: C / GRIDLOCK (48-second study)
- stage_02: LOCKED CURRENT / MOTION V5 (117-second full loop)
- stage_03: B / PHASE STEPS (46-second study)
- reference_original_stage01: original BLACK CIRCUIT sample for balance comparison

Open each .rpp in REAPER. Install/enable Magical 8bit Plug 2 VST3; remaining FX
are bundled REAPER/JS effects. All note data and plugin settings are embedded.
Each project contains THREE consecutive cycles for settled rendering; this is
not a three-times-longer composition. *_source.wav retains that full render.
*_master.wav is the extracted one-cycle listening version. MIDI and score files
are included for further editing. Render destinations point into these folders.
The original stage-01 reference master is stage_01_master.wav.

BGM has NOT been installed in the game. Stage 01/03 are still short studies.
The first eight approved SFX are installed; game music and audio defaults remain
unchanged. Google Drive uploads require an explicit request.

Other MIDI/RPP/score candidates remain under ../candidates for recoverability,
but their disposable renders and audition bundles were removed. Production
scripts remain under tools/audio. Selected source WAVs and editable projects
are preserved here; effect production sources are in ../production_se.
''',encoding='utf-8')
    disposable=[]
    for folder in [BASE/'candidates',BASE/'review',BASE/'sample',BASE/'probe']:
        for p in folder.rglob('*'):
            if p.is_file() and (p.suffix.lower() in ['.wav','.mp3','.ogg','.avi','.mp4','.png','.zip','.reapeaks','.rpp-bak'] or p.name in ['index.html','playlist.m3u8']):
                disposable.append(p)
    disposable+=list(BASE.glob('*.zip'))
    rows=[dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size) for p in disposable]
    (BASE/'cleanup_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print(json.dumps(dict(selected=str(SELECTED),effects=len(EFFECTS),cleanup_files=len(rows),cleanup_bytes=sum(r['bytes'] for r in rows))))

if __name__=='__main__':main()
