"""A full stage-02 arrangement with articulated hooks and interlocking layers."""
import copy
import hashlib
import json
from sample_score import ROOT,lua,write_midi

OUT=ROOT/'docs/audio/candidates/02-motion-v5'
SOURCE=ROOT/'docs/audio/candidates/stage-v3/02_locked_current/score.json'

# Sixteenth-note positions, pitch above C4, length in quarter-note beats.
# Four-bar call/response identities, not a sustained anthem or random arpeggio.
HOOK=[
 [(0,7,.32),(2,7,.16),(3,12,.20),(5,10,.30),(7,7,.16),(8,3,.30),(10,5,.17),(11,7,.30),(14,10,.30)],
 [(0,12,.32),(2,10,.17),(3,7,.30),(6,5,.30),(8,3,.32),(10,5,.17),(11,7,.17),(13,5,.17),(14,3,.30)],
 [(0,7,.32),(2,7,.16),(3,12,.20),(5,10,.30),(7,7,.16),(8,12,.30),(10,14,.17),(11,15,.30),(14,14,.30)],
 [(0,12,.32),(3,10,.30),(5,7,.30),(7,5,.16),(8,3,.30),(10,2,.17),(11,0,.30),(14,7,.30)],
]
ANSWER=[
 [(0,12,.30),(1,12,.16),(3,10,.30),(6,7,.30),(8,10,.30),(11,12,.30),(14,10,.30)],
 [(0,8,.32),(3,7,.30),(5,5,.30),(7,3,.16),(8,5,.30),(10,7,.16),(11,8,.30),(14,7,.30)],
 [(0,7,.30),(2,10,.16),(3,12,.30),(6,15,.30),(8,14,.30),(11,12,.30),(14,10,.30)],
 [(0,7,.30),(3,5,.30),(5,3,.30),(7,2,.16),(8,0,.38),(11,7,.16),(12,10,.16),(14,7,.30)],
]


def build():
    original=json.loads(SOURCE.read_text());s=copy.deepcopy(original)
    s.update(id='02_locked_current_v5',title='LOCKED CURRENT / MOTION V5',
       description='The original opening and bass/drums, now with a clipped four-bar hook, answering pulse figures and short chord reinforcement.')
    tracks=s['tracks']
    for i in [8,9,10]:tracks[i]['notes']=[n for n in tracks[i]['notes'] if n[0]<32]
    lead=tracks[9]
    lead.update(name='10 Cut signal',level_db=-24,voice='arp',pan=.06,
       patch=dict(osc=0,duty=1,bend=0,attack=.001,decay=.09,sustain=.28,release=.01,filter=4000,top=-6),
       echo=dict(time=60000/s['bpm']*.5,wet=-22,feedback=-19,cutoff=3300,highpass=750))
    tracks[8]['name']='09 Short pressure chords'
    tracks.append(dict(name='13 Chord flash',voice='stab',level_db=-30,pan=-.23,notes=[],
        patch=dict(duty=.5,bend=0,attack=.003,decay=.085,sustain=.15,release=.025,filter=3200,top=-8),echo=False))
    tracks.append(dict(name='14 Octave punctuation',voice='sub',level_db=-30,pan=.23,notes=[],
        patch=dict(bend=0,attack=.001,decay=.07,sustain=.25,release=.012),echo=False))
    counter=copy.deepcopy(original['tracks'][10])
    counter.update(name='15 Answering clock',level_db=-31,notes=[])
    counter['patch'].update(duty=.5,decay=.065,sustain=.1,release=.01,bend=0)
    tracks.append(counter)
    def n(i,b,p,d,v):
        if b<320:tracks[i]['notes'].append([round(b,6),p,min(d,320-b),v])
    for bar in range(8,80):
        b=bar*4;phrase=bar%16
        # Two-bar gaps let accompaniment answer; a short middle breakdown keeps
        # the bass/drums intact and makes the returning hook perceptible.
        breakdown=32<=bar<40
        call=not breakdown and (bar%8<6 or bar>=64)
        motif=ANSWER if 24<=bar<32 or 48<=bar<56 else HOOK
        if call:
            for j,(step,p,d) in enumerate(motif[bar%4]):
                # Final return keeps the hook, doubling only selected accents.
                n(9,b+step/4,60+p,d,96 if step in [0,8] else 84)
                if (bar>=56 and step in [0,8]) or (bar in [14,30,46,62] and j==0):
                    n(13,b+step/4,72+p,min(d,.22),65)
        # Counterline occupies the hook's spaces; no constant parallel-third doubling.
        if breakdown or not call:
            steps=[(0,7),(3,10),(6,12),(8,7),(11,5),(14,3)]
            for step,p in steps:n(14,b+step/4,60+p,.20,76)
        elif bar%4 in [1,3]:
            for step,p in [(12,19),(15,15)]:n(14,b+step/4,60+p,.13,64)
        if not breakdown:
            for step in ([.5,2.75] if bar%2==0 else [1.75]):
                for p in [48,55]:n(8,b+step,p,.15,82)
            if bar%4 in [0,2]:
                chord=[60,63,70] if bar%8<4 else [58,65,67]
                for p in chord:n(12,b+2.75,p,.24,72)
        elif bar%2==0:
            for p in [48,55]:n(8,b+2.75,p,.13,68)
    for track_index,t in enumerate(tracks):
        if track_index>=8:t['notes'].sort(key=lambda v:(v[0],v[1]))
        assert t['notes']
        assert all(0<=b<320 and 0<=p<=127 and d>0 and b+d<=320 and 0<v<=127 for b,p,d,v in t['notes'])
    for i in range(8):assert tracks[i]==original['tracks'][i], 'Drum/bass changed'
    for i in range(12):
        assert sorted([n for n in tracks[i]['notes'] if n[0]<32],key=lambda v:(v[0],v[1]))==sorted([n for n in original['tracks'][i]['notes'] if n[0]<32],key=lambda v:(v[0],v[1]))
    assert max(n[2] for n in lead['notes'])<=.4
    return s


def main():
    s=build();folder=OUT/s['id'];folder.mkdir(parents=True,exist_ok=True)
    raw=json.dumps(s,indent=2)
    (folder/'score.json').write_text(raw,encoding='utf-8')
    (folder/'score.lua').write_text('return '+lua(s),encoding='utf-8')
    write_midi(s,folder/(s['id']+'.mid'))
    c={k:v for k,v in s.items() if k!='tracks'}
    c['score_sha256']=hashlib.sha256(raw.encode()).hexdigest()
    (OUT/'catalog.json').write_text(json.dumps([c],indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua([c]),encoding='utf-8')
    print(f"{s['seconds']:.1f}s, 15 tracks, unchanged drum/bass data, clipped lead <= 0.4 beats")


if __name__=='__main__':main()
