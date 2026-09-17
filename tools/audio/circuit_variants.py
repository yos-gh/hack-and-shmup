"""Three short stage-01 studies; stage 02 and prior renders remain unchanged."""
import copy
import hashlib
import json
from sample_score import ROOT,lua,write_midi

OUT=ROOT/'docs/audio/candidates/01-variants-v1'
SOURCE=ROOT/'docs/audio/candidates/stage-v3/01_circuit_drive/score.json'

# Sixteenth positions, semitones above D4, lengths in beats. Four-bar identities.
THEMES=[
 [
  [(0,0,.28),(2,0,.16),(3,7,.28),(6,3,.28),(8,2,.28),(10,0,.16),(11,7,.28),(14,5,.28)],
  [(0,3,.28),(3,2,.28),(5,0,.28),(8,7,.28),(10,8,.16),(11,7,.28),(14,3,.28)],
  [(0,0,.28),(2,0,.16),(3,7,.28),(6,3,.28),(8,10,.28),(10,7,.16),(11,5,.28),(14,3,.28)],
  [(0,2,.28),(3,3,.28),(5,5,.28),(8,7,.28),(10,5,.16),(11,2,.28),(14,0,.28)],
 ],
 [
  [(0,7,.45),(2,10,.18),(3,12,.45),(6,10,.35),(8,7,.45),(11,5,.35),(14,3,.35)],
  [(0,5,.45),(3,7,.35),(5,8,.35),(8,7,.45),(10,5,.18),(11,3,.35),(14,2,.35)],
  [(0,7,.45),(2,10,.18),(3,12,.45),(6,14,.35),(8,15,.45),(11,14,.35),(14,12,.35)],
  [(0,10,.45),(3,7,.35),(5,5,.35),(8,3,.45),(10,5,.18),(11,2,.35),(14,0,.35)],
 ],
 [
  [(0,12,.25),(3,12,.25),(6,13,.25),(8,12,.25),(11,7,.25),(14,10,.25)],
  [(0,7,.25),(3,8,.25),(6,7,.25),(8,5,.25),(11,3,.25),(14,1,.25)],
  [(0,12,.25),(3,12,.25),(6,15,.25),(8,13,.25),(11,12,.25),(14,7,.25)],
  [(0,8,.25),(3,7,.25),(6,5,.25),(8,3,.25),(11,1,.25),(14,0,.25)],
 ],
]


def build(index,original):
    s=copy.deepcopy(original)
    s.update(id=['a_razor','b_overrun','c_gridlock'][index],
        title=['A / CIRCUIT DRIVE - RAZOR','B / CIRCUIT DRIVE - OVERRUN','C / CIRCUIT DRIVE - GRIDLOCK'][index],
        bars=32,seconds=48.0,description=[
          'A sharp low-register pulse hook, repeated rhythmic cells and an answering upper voice.',
          'A moving minor-key game melody, articulated rising phrases and brief octave reinforcement.',
          'Interlocking rave chords, a semitone hook and a clock-like answer; greater emphasis on layers.'][index])
    tracks=s['tracks']
    for t in tracks:
        t['notes']=[n for n in t['notes'] if n[0]<128]
        for n in t['notes']:n[2]=min(n[2],128-n[0])
    for i in [8,9,10]:tracks[i]['notes']=[n for n in tracks[i]['notes'] if n[0]<32]
    lead=tracks[9]
    lead.update(name='10 Main hook',voice='arp',level_db=[-24,-25,-27][index],
        patch=dict(osc=0,duty=[0,.5,1][index],bend=0,attack=.001,decay=.1,
                   sustain=.3,release=.012,filter=3900,top=-7),
        echo=dict(time=140.625,wet=-23,feedback=-18,cutoff=3400))
    counter=copy.deepcopy(original['tracks'][10])
    counter.update(name='13 Answer signal',notes=[],level_db=[-30,-32,-28][index],pan=.25)
    counter['patch'].update(bend=0,duty=.5,release=.01,decay=.06)
    tracks.append(counter)
    tracks.append(dict(name='14 Chord accents',voice='stab',level_db=[-32,-32,-29][index],pan=-.25,notes=[],
       patch=dict(bend=0,duty=1,attack=.002,decay=.075,sustain=.15,release=.025,filter=3200,top=-8),echo=False))
    tracks.append(dict(name='15 Octave body',voice='sub',level_db=-32,pan=.08,notes=[],
       patch=dict(bend=0,attack=.001,decay=.065,sustain=.2,release=.01),echo=False))
    def n(t,b,p,d,v):
        if b<128:tracks[t]['notes'].append([round(b,5),p,min(d,128-b),v])
    for bar in range(8,32):
        b=bar*4;root=62-(2 if bar%16 in [14,15] else 0)
        answer=16<=bar<24
        sparse=answer and bar%4 in [1,3]
        for j,(step,p,d) in enumerate(THEMES[index][bar%4]):
            if sparse and j>=3:continue
            if answer and bar%4==2 and j>=4:p=max(0,p-2)
            n(9,b+step/4,root+p,d,94 if step in [0,8] else 84)
            if bar>=24 and step in [0,8]:n(14,b+step/4,root+p+12,min(d,.22),68)
        if sparse:
            pitches=[[7,10,7,3],[12,10,7,5],[7,8,7,1]][index]
            for j,p in enumerate(pitches):n(12,b+2+j*.5,root+p,.20,78)
        elif bar%2:
            for step,p in [(12,19),(15,15)]:n(12,b+step/4,root+p,.13,62)
        # Retain a rhythmic chord bed, with the layered variant more assertive.
        for step in ([.5,2.75] if bar%2==0 else [1.75]):
            for p in [root-12,root-5]:n(8,b+step,p,.15,80)
        chord=[root,root+3,root+7] if index!=2 else [root,root+7,root+10]
        steps=([.75,2.5] if bar%2==0 else [1.5,3.25]) if index==2 else ([2.75] if bar%4==0 else [])
        for step in steps:
            for p in chord:n(13,b+step,p,.20,74)
    for i,t in enumerate(tracks):
        assert t['notes'],t['name']
        assert all(0<=b<128 and 0<=p<=127 and d>0 and b+d<=128 and 0<v<=127 for b,p,d,v in t['notes'])
        if i<8:
            expected=copy.deepcopy(original['tracks'][i]);expected['notes']=[n for n in expected['notes'] if n[0]<128]
            for n0 in expected['notes']:n0[2]=min(n0[2],128-n0[0])
            assert t==expected
    assert min(n[0] for n in lead['notes'])==32
    return s


def main():
    original=json.loads(SOURCE.read_text());OUT.mkdir(parents=True,exist_ok=True);catalog=[]
    for i in range(3):
        s=build(i,original);folder=OUT/s['id'];folder.mkdir(exist_ok=True)
        raw=json.dumps(s,indent=2)
        (folder/'score.json').write_text(raw,encoding='utf-8')
        (folder/'score.lua').write_text('return '+lua(s),encoding='utf-8')
        write_midi(s,folder/(s['id']+'.mid'))
        c={k:v for k,v in s.items() if k!='tracks'};c['score_sha256']=hashlib.sha256(raw.encode()).hexdigest();catalog.append(c)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua(catalog),encoding='utf-8')
    print('Three 48-second stage-01 studies; drum/bass preservation verified.')


if __name__=='__main__':main()
