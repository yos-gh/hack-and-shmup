"""Three breakbeat studies: rhythmic riff/arp texture, no singing lead."""
import copy
import hashlib
import json
from sample_score import ROOT,lua,write_midi

OUT=ROOT/'docs/audio/candidates/03-variants-v1'
SOURCE=ROOT/'docs/audio/candidates/stage-v3/03_breaker_run/score.json'


def build(index,original):
    s=copy.deepcopy(original)
    s.update(id=['a_cutback','b_phase_steps','c_scramble'][index],
        title=['A / CUTBACK','B / PHASE STEPS','C / SCRAMBLE'][index],bars=32,seconds=32*240/s['bpm'],
        description=['A low, clipped riff locking into broken drums, with short answering ticks.',
        'Gated minor arpeggios in repeating cells; gaps keep the snare and ghost notes exposed.',
        'Metallic pulse fragments and rhythmic retriggers; texture and interruption rather than melody.'][index])
    tracks=s['tracks']
    for t in tracks:
        t['notes']=[n for n in t['notes'] if n[0]<128]
        for n in t['notes']:n[2]=min(n[2],128-n[0])
    for i in [8,9,10]:tracks[i]['notes']=[]
    tracks[8].update(name='09 Chord punctuation',level_db=-30,
        patch=dict(bend=0,duty=1,attack=.001,decay=.05,sustain=0,release=.012,filter=2800,top=-8),echo=False)
    tracks[9].update(name='10 Rhythmic cell',voice='arp',level_db=[-23,-27,-27][index],pan=-.12,
        patch=dict(osc=0,duty=[1,.5,0][index],bend=0,attack=.001,decay=[.06,.045,.026][index],
            sustain=.1,release=.006,filter=[2800,4000,3300][index],top=-7),echo=False)
    tracks[10].update(name='11 Interleaved answer',voice='arp',level_db=[-31,-33,-30][index],pan=.22,
        patch=dict(osc=.5 if index==0 else 0,duty=1,bend=0,attack=.001,decay=.04,
            sustain=0,release=.006,filter=3400,top=-8),echo=False)
    def n(t,b,p,d,v):
        tracks[t]['notes'].append([round(b,6),p,min(d,128-b),v])
    for bar in range(32):
        b=bar*4;root=52-(2 if bar%16 in [14,15] else 0)
        # Four bars introduce the original drums/bass. The core identity arrives
        # at bar eight; two answering bars in the middle create rhythmic space.
        if bar<4:continue
        intro=bar<8
        reduced=16<=bar<20
        if index==0:
            pattern=[(0,0),(.75,0),(1.5,7),(2.25,0),(2.75,3),(3.5,0)]
            if bar%4==3:pattern=[(0,0),(.75,0),(1.5,7),(2.5,3),(3.25,0),(3.5,0),(3.75,0)]
            for j,(step,p) in enumerate(pattern):
                if intro and j>1 or reduced and j%2:continue
                n(9,b+step,root+p,.17 if j%2==0 else .12,96 if j==0 else 82)
            if not intro:
                for step,p in [(1.25,12),(3,7)]:n(10,b+step,root+p,.10,72)
        elif index==1:
            seq=[0,7,12,3,7,12,0,7]
            for j in range(16):
                if j in [4,5,12,13] or intro and j>=4 or reduced and j>=8:continue
                # Same cell, alternate gating; no long melodic rise or cadence.
                if bar%4==3 and j in [2,3,10,11]:continue
                n(9,b+j*.25,root+12+seq[j%8],.11,85 if j%4==0 else 68+j%3*4)
            if not intro:
                for step,p in [(1.25,0),(3.25,7)]:n(10,b+step,root+12+p,.14,70)
        else:
            pattern=[(0,0),(.1875,0),(.75,1),(1.5,7),(2.25,0),(2.4375,0),(3.25,6)]
            for j,(step,p) in enumerate(pattern):
                if intro and j>=2 or reduced and j in [2,3,6]:continue
                n(9,b+step,root+12+p,.075 if j in [1,5] else .12,88 if j%2==0 else 65)
            if not intro:
                for step,p in [(1,7),(2.75,1),(3.75,0)]:n(10,b+step,root+12+p,.085,72)
        if not intro and not reduced and bar%4==2:
            for p in [root,root+7]:n(8,b+2.75,p,.13,74)
        if bar>=24 and bar%4==3:
            for j in range(3):n(10,b+3.25+j*.25,root+12+(7 if index==1 else 0),.085,66+j*6)
    for i,t in enumerate(tracks):
        assert t['notes']
        assert all(0<=b<128 and 0<=p<=127 and 0<d<=128-b and 0<v<=127 for b,p,d,v in t['notes'])
        if i<8:
            expected=copy.deepcopy(original['tracks'][i]);expected['notes']=[n for n in expected['notes'] if n[0]<128]
            for note in expected['notes']:note[2]=min(note[2],128-note[0])
            assert t==expected
    assert all(n[2]<=.17 for i in [8,9,10] for n in tracks[i]['notes'])
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
    print('Three 46.3-second breakbeat studies; original bass/drums verified.')


if __name__=='__main__':main()
