"""Ten original underground chip tracks for selection; never touches game assets."""
from pathlib import Path
import hashlib
import json
from sample_score import lua, write_midi

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/audio/candidates/underground-v1'

CATALOG = [
    ('01_sublevel_09', 'SUBLEVEL 09', 160, 80, 38, 'warehouse',
     'A dry warehouse groove, heavy sub pulse and restrained metallic signals.'),
    ('02_acid_crawl', 'ACID CRAWL', 164, 80, 36, 'acid',
     'A twisting pulse-bass sequence with chromatic tension and clipped percussion.'),
    ('03_pirate_signal', 'PIRATE SIGNAL', 166, 80, 40, 'breaks',
     'Pirate-radio breakbeats, ghost snares and broken chip fragments.'),
    ('04_iron_chamber', 'IRON CHAMBER', 168, 80, 37, 'industrial',
     'Metallic machine rhythms, short-cycle noise and a low concrete throb.'),
    ('05_dead_channel', 'DEAD CHANNEL', 158, 80, 35, 'dub',
     'Dark dub chords, filtered echoes and a deep offbeat bassline.'),
    ('06_black_voltage', 'BLACK VOLTAGE', 172, 88, 38, 'hard',
     'A relentless kick, octave bass and abrasive minor-second stabs.'),
    ('07_phase_drift', 'PHASE DRIFT', 162, 80, 41, 'hypnotic',
     'Three-against-four pulses and an evolving, low-register hypnotic sequence.'),
    ('08_last_train', 'LAST TRAIN', 174, 88, 36, 'rave',
     'Ominous rave chords, rolling percussion and a brief distorted transmission.'),
    ('t1_cold_boot', 'COLD BOOT', 96, 48, 38, 'title_cold',
     'Sparse terminal pulses, a distant minor-second motif and cold sub resonance.'),
    ('t2_below_the_grid', 'BELOW THE GRID', 108, 56, 35, 'title_dub',
     'Muted chord echoes and a slow, subterranean heartbeat.'),
]


class Score:
    def __init__(self, definition):
        self.id, self.title, self.bpm, self.bars, self.root, self.style, self.description = definition
        self.tracks = []

    def track(self, name, voice, level, pan=0, patch=None, echo=None):
        data = dict(name=name, voice=voice, level_db=level, pan=pan, notes=[],
                    patch=patch or {}, echo=echo or False)
        self.tracks.append(data)
        return data['notes']

    def hit(self, track, beat, pitch, duration, velocity=100):
        if beat >= self.bars*4:
            return
        duration = min(duration, self.bars*4-beat)
        track.append([round(beat, 6), int(pitch), round(duration, 6), int(velocity)])

    def data(self):
        return dict(id=self.id, title=self.title, bpm=self.bpm, bars=self.bars,
                    seconds=self.bars*240/self.bpm, root=self.root, style=self.style,
                    role='title' if self.style.startswith('title') else 'stage',
                    description=self.description, tracks=self.tracks)


def stage(definition):
    s = Score(definition)
    style = s.style
    h = s.hit
    # Lower and darker than the first approved reference. No long bright lead.
    kick = s.track('01 Foundation kick', 'kick', -8,
                   patch={'decay': .17 if style in ['warehouse','dub'] else .125})
    click = s.track('02 Kick grit', 'kick_edge', -30,
                    patch={'filter': 2600, 'top': -10})
    snare = s.track('03 Snare shell', 'snare_body', -21)
    noise = s.track('04 Snare dust', 'snare_noise', -21,
                    patch={'decay': .075, 'filter': 3300, 'top': -9})
    hats = s.track('05 Ticking metal', 'hat', -27, .18,
                   patch={'filter': 4400, 'top': -10, 'algorithm': 1})
    open_hat = s.track('06 Open noise', 'open_hat', -29, -.2,
                       patch={'filter': 3400, 'top': -9})
    sub = s.track('07 Sub floor', 'sub', -12,
                  patch={'decay': .12, 'sustain': .38, 'release': .018})
    bass = s.track('08 Pulse mechanism', 'bass', -20,
                   patch={'duty': .5 if style in ['warehouse','dub'] else 0,
                          'decay': .065, 'sustain': .12, 'filter': 1700,
                          'top': -12, 'saturation': .65, 'bend': 1 if style=='acid' else 0})
    stabs = s.track('09 Pressure chords', 'stab', -29, -.2,
                    patch={'decay': .06, 'release': .08 if style=='dub' else .025,
                           'filter': 1400 if style=='dub' else 2500, 'top': -12,
                           'saturation': .45},
                    echo={'time': 60000/s.bpm*(.75 if style=='dub' else .375),
                          'wet': -8 if style=='dub' else -19,
                          'feedback': -7 if style=='dub' else -16, 'cutoff': 2600})
    signal = s.track('10 Signal motif', 'lead', -30, .15,
                     patch={'duty': 0, 'decay': .045, 'sustain': .12, 'release': .022,
                            'filter': 3200, 'top': -9, 'bend': 0},
                     echo={'time': 60000/s.bpm*.75, 'wet': -15,
                           'feedback': -11, 'cutoff': 3400})
    machine = s.track('11 Machine cycle', 'spark', -31, -.3,
                      patch={'decay': .028, 'bend': 0, 'algorithm': 1,
                             'filter': 3000, 'top': -11})

    bass_patterns = {
        'warehouse': [(0,0,.38),(.75,0,.18),(1.5,0,.27),(2,0,.35),(2.75,1,.17),(3.5,0,.26)],
        'acid': [(0,0,.18),(.5,12,.16),(.75,1,.25),(1.25,0,.16),(1.5,7,.22),
                 (2,0,.22),(2.5,13,.18),(2.75,12,.16),(3.25,1,.17),(3.75,0,.18)],
        'breaks': [(0,0,.42),(.75,0,.2),(1.75,7,.32),(2.5,0,.3),(3.25,-2,.22)],
        'industrial': [(0,0,.20),(.75,0,.2),(1.5,6,.18),(2.25,0,.2),(3,1,.18),(3.5,0,.18)],
        'dub': [(.5,0,.48),(1.5,0,.34),(2.5,-2,.5),(3.5,0,.28)],
        'hard': [(0,0,.24),(.5,12,.16),(1,0,.24),(1.5,12,.16),(2,0,.24),
                 (2.5,12,.16),(3,1,.24),(3.5,0,.16)],
        'hypnotic': [(0,0,.24),(.75,7,.24),(1.5,0,.24),(2.25,1,.24),(3,0,.24),(3.75,7,.18)],
        'rave': [(0,0,.25),(.5,0,.2),(1.25,7,.2),(1.75,12,.2),(2.5,0,.3),(3.25,1,.18)],
    }
    # Distinct authored motifs, stated sparingly, rather than eight transpositions.
    motifs = {
        'warehouse': [(0,12,.16),(1.75,13,.10),(3,12,.12)],
        'acid': [(.25,24,.1),(1,13,.15),(2.75,12,.18),(3.5,19,.1)],
        'breaks': [(0,19,.13),(.75,24,.12),(1.25,22,.11),(2.5,13,.15),(3.25,12,.18)],
        'industrial': [(0,12,.07),(.75,18,.07),(1.5,13,.09),(3.25,12,.08)],
        'dub': [(.5,12,.25),(2.75,10,.3)],
        'hard': [(.5,24,.10),(1.5,25,.10),(2.25,19,.1),(3,24,.12)],
        'hypnotic': [(0,19,.18),(.75,12,.12),(1.5,13,.14),(2.25,19,.12),(3,12,.18)],
        'rave': [(0,24,.18),(.75,22,.16),(1.5,19,.17),(2.25,13,.18),(3.25,12,.24)],
    }
    for bar in range(s.bars):
        b = bar*4
        phrase = bar % 16
        section = bar // 16
        # Pressure-release section thins upper voices, never silences the rhythm.
        thin = section == 2 and phrase < 8
        kick_steps = [0,1,2,3]
        if style=='breaks':
            kick_steps = [0,1.75,2.5,3.5] if bar%2 else [0,.75,2,2.75]
        elif style=='industrial' and bar%4==3:
            kick_steps = [0,1,2.25,3]
        elif style=='rave' and phrase>=12:
            kick_steps = [0,1,1.75,2,3,3.5]
        if phrase==15:
            kick_steps = [x for x in kick_steps if x<3]+[3.5]
        for beat in kick_steps:
            h(kick,b+beat,30 if style!='hard' else 32,.29,112)
            h(click,b+beat,75,.024,85)
        snare_steps = [1,3] if style not in ['warehouse','dub'] else [3]
        for beat in snare_steps:
            h(snare,b+beat,49,.105,96)
            h(noise,b+beat,68,.15,100)
        if style=='breaks':
            for beat in [1.5,2.75,3.75]:
                h(noise,b+beat,71,.065,48+(bar%3)*6)
        steps = range(16) if style in ['breaks','hard','rave'] and not thin else range(0,16,2)
        for step in steps:
            if step%4==0 and style in ['warehouse','dub']: continue
            swing = .035 if style in ['breaks','dub'] and step%2 else 0
            h(hats,b+step/4+swing,84+(step%3),.028,47+(step%4)*9)
        if not thin:
            for beat in [.5,1.5,2.5,3.5]:
                if style=='industrial' and beat==1.5: continue
                h(open_hat,b+beat,77,.14,74)
        root = s.root
        # Keep a tonal centre; no cheerful four-chord cycle.
        if style=='dub' and phrase>=12: root-=2
        elif style=='rave' and phrase in [6,7,14,15]: root-=2
        elif style=='breaks' and phrase>=12: root+=1
        elif phrase==15: root+=1 if style in ['acid','industrial'] else 0
        pattern = bass_patterns[style]
        for j,(beat,interval,length) in enumerate(pattern):
            if style=='acid' and phrase%4==3 and j in [2,7]: interval+=12
            h(bass,b+beat,root+interval,length,94 if j%3==0 else 76)
            if interval<7 or style=='hard':
                h(sub,b+beat,root-12+(interval if interval<7 else 0),length+.06,102)
        if not thin and (bar%2==0 or style in ['dub','hard']):
            if style=='dub':
                chord_steps=[.75] if bar%4 else [.75,2.5]
                chord=[12,15,22]
            elif style=='rave':
                chord_steps=[.5,2.75] if bar%2==0 else [1.75]
                chord=[12,15,19]
            elif style=='industrial':
                chord_steps=[.75,2.25]; chord=[12,18]
            elif style=='hard':
                chord_steps=[.5,2.5]; chord=[12,13]
            else:
                chord_steps=[1.75] if bar%4 else [.5,3.25]; chord=[12,19]
            for beat in chord_steps:
                for interval in chord:
                    h(stabs,b+beat,root+interval,.14 if style!='dub' else .30,82)
        if section in [1,3,4,5] and (bar%4>=2 or style in ['acid','rave']):
            for beat,interval,length in motifs[style]:
                h(signal,b+beat,root+interval,length,74 if phrase<12 else 86)
        if not thin and (style in ['industrial','hypnotic'] or phrase>=12):
            for step in range(16):
                active = (bar*16+step)%3==0 if style=='hypnotic' else step in [0,3,6,10,13]
                if active: h(machine,b+step/4,61+((bar+step)%4)*3,.045,64)
        if phrase in [7,15]:
            for j in range(4):
                h(noise,b+3+j/4,68-j,.06,51+j*11)
        # End-of-phrase interruptions and a second-half answer alter the groove.
        if section>=3 and phrase%4==3:
            h(machine,b+3.5,50,.08,85)
            h(signal,b+3.75,root+13,.09,66)
    return s.data()


def title(definition):
    s=Score(definition); h=s.hit
    cold=s.style=='title_cold'
    drone=s.track('01 Buried fundamental','sub',-20,
                  patch={'attack':.15,'decay':.8,'sustain':.5,'release':.45})
    pulse=s.track('02 Remote pulse','kick',-27,
                  patch={'decay':.25,'bend':9,'bendtime':.11,'filter':900,'top':-16})
    chord=s.track('03 Faded memory','stab',-33,-.22,
                  patch={'attack':.05,'decay':.35,'sustain':.12,'release':.6,'filter':1100,'top':-15},
                  echo={'time':60000/s.bpm*.75,'wet':-7,'feedback':-6,'cutoff':2200,'highpass':300})
    notes=s.track('04 Terminal fragments','arp',-29,.2,
                  patch={'decay':.12,'release':.16,'filter':2400,'top':-12},
                  echo={'time':60000/s.bpm*1.5,'wet':-10,'feedback':-7,'cutoff':2800})
    dust=s.track('05 Distant dust','spark',-40,-.32,
                 patch={'attack':.02,'decay':.20,'bend':0,'filter':1700,'top':-15})
    for bar in range(s.bars):
        b=bar*4; section=bar//8; root=s.root-(2 if section%3==2 else 0)
        if bar%2==0: h(drone,b,root-12,6.5,83)
        if not cold or bar%2==0: h(pulse,b,25,.55,75)
        if not cold and bar%2: h(pulse,b+2.75,25,.4,54)
        if bar%4==0:
            for interval in ([12,19,25] if cold else [12,15,22]):
                h(chord,b+1.5,root+interval,1.2,72)
        if bar%4 in [1,3]:
            melody=[(0,24),(.75,25),(2.5,19)] if cold else [(0,19),(1.5,15),(2.75,12)]
            for offset,interval in melody:
                if section%2==0 and offset==.75: continue
                h(notes,b+offset,root+interval,.18 if cold else .30,65)
        if bar%4==3:
            h(dust,b+3,55,.20,50)
        if section>=3 and bar%8==6:
            h(notes,b+2.25,root+13,.4,58)
    return s.data()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    catalog=[]
    for definition in CATALOG:
        data=title(definition) if definition[5].startswith('title') else stage(definition)
        folder=OUT/data['id']; folder.mkdir(exist_ok=True)
        serialized=json.dumps(data,indent=2,ensure_ascii=False)
        (folder/'score.json').write_text(serialized,encoding='utf-8')
        (folder/'score.lua').write_text('return '+lua(data),encoding='utf-8')
        write_midi(data,folder/(data['id']+'.mid'))
        assert 112<=data['seconds']<=128
        for track in data['tracks']:
            assert track['notes'], track['name']
            assert all(0<=n[1]<=127 and 0<n[2] and 0<n[3]<=127 for n in track['notes'])
        metadata={k:v for k,v in data.items() if k!='tracks'}
        metadata['note_count']=sum(len(t['notes']) for t in data['tracks'])
        metadata['score_sha256']=hashlib.sha256(serialized.encode()).hexdigest()
        catalog.append(metadata)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua(catalog),encoding='utf-8')
    print('\n'.join(f"{c['id']}: {c['seconds']:.1f}s, {c['note_count']} notes" for c in catalog))


if __name__=='__main__': main()
