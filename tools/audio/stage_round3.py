"""Three stage-only studies returning to the first BLACK CIRCUIT prototype."""
import hashlib
import json
import sample_score
from sample_score import ROOT,lua,write_midi

OUT=ROOT/'docs/audio/candidates/stage-v3'


def build(i):
    sample_score.BARS=80
    s=sample_score.make_score()
    s.update(id=['01_circuit_drive','02_locked_current','03_breaker_run'][i],
             title=['CIRCUIT DRIVE','LOCKED CURRENT','BREAKER RUN'][i],
             bpm=[160,164,166][i],role='stage',root=[38,36,40][i],
             description=[
              'Original-sample drive, round triangle kick, dry 25-percent pulse bass and a restrained signal melody.',
              'A locked two-bar bass figure, broad square-wave body, heavy low kick and short clap-like snare.',
              'Broken beats, tight higher kick, crisp snare and driven triangle bass with a clipped melodic answer.'][i])
    s['seconds']=80*240/s['bpm']
    tracks=s['tracks']
    for t in tracks:
        t['notes']=[];t['patch']={};t['echo']=False
    # Audible instrument changes, rather than merely changing note patterns.
    patches=[
      [{'decay':.15,'bend':24,'bendtime':.025}, {},
       {'decay':.07,'bend':12,'bendtime':.018}, {'decay':.10,'algorithm':.5},
       {'decay':.025,'algorithm':1}, {'decay':.10,'algorithm':.5},
       {'decay':.11,'sustain':.50,'release':.012},
       {'osc':0,'duty':.5,'decay':.10,'sustain':.22,'bend':0,'filter':3500,'top':-5}],
      [{'decay':.21,'bend':19,'bendtime':.045}, {'decay':.008,'filter':2400,'top':-10},
       {'decay':.035,'bend':7,'bendtime':.008}, {'decay':.065,'algorithm':.5,'filter':3800,'top':-6},
       {'decay':.016,'algorithm':.5}, {'decay':.07,'algorithm':1},
       {'decay':.14,'sustain':.35,'release':.025},
       {'osc':0,'duty':1,'decay':.16,'sustain':.32,'release':.02,'bend':0,'filter':2100,'top':-9,'saturation':.28}],
      [{'decay':.085,'bend':24,'bendtime':.014}, {'decay':.018,'algorithm':1},
       {'decay':.09,'bend':18,'bendtime':.012}, {'decay':.045,'algorithm':1,'filter':4600,'top':-6},
       {'decay':.011,'algorithm':1}, {'decay':.06,'algorithm':.5},
       {'decay':.08,'sustain':.2,'release':.01},
       {'osc':.5,'decay':.13,'sustain':.65,'release':.025,'bend':0,'saturation':.65,'filter':3500,'top':-3}],
    ][i]
    for t,p in zip(tracks,patches):t['patch']=p
    tracks[7]['level_db']=[-20,-23,-13][i]
    tracks[6]['level_db']=[-14,-17,-20][i]
    tracks[3]['level_db']=[-18,-20,-17][i]
    tracks[8]['patch']=dict(bend=0,duty=1,decay=.12,sustain=.15,release=.04,filter=3200,top=-6)
    tracks[8]['level_db']=-27
    tracks[9]['patch']=dict(bend=0,duty=[1,.5,1][i],attack=.003,decay=.16,
                           sustain=.45,release=.035,filter=3800,top=-5)
    tracks[9]['level_db']=[-25,-27,-25][i]
    tracks[9]['echo']=dict(time=60000/s['bpm']*.75,wet=-24,feedback=-20,cutoff=3400)
    tracks[10]['patch']=dict(bend=0,duty=1,decay=.06,filter=3600,top=-7)
    tracks[10]['level_db']=-34
    tracks[11]['patch']=dict(decay=.055,bend=0,filter=3500,top=-8)
    tracks[11]['level_db']=-31
    def n(t,b,p,d,v):
        if b<320:tracks[t]['notes'].append([round(b,5),p,round(min(d,320-b),5),v])
    # Compact two-bar motifs: no original high-octave jaunty hook, no pitch drift.
    melodies=[[(0,24,.65),(1.5,24,.35),(2.5,31,.6),(4,29,.65),(5.5,26,.35),(6.5,24,.7)],
              [(0,24,.7),(2,24,.4),(3.5,27,.4),(4.5,26,.7),(6,24,.65)],
              [(.5,24,.3),(1.25,31,.4),(2.75,29,.45),(4.25,26,.45),(5.5,24,.6),(7,24,.3)]]
    for bar in range(80):
        b=bar*4;section=bar//16;phrase=bar%16
        root=s['root']
        if i!=1 and phrase in [14,15]:root-=2
        thin=section==2 and phrase<8
        ks=[0,1,2,3] if i!=2 else ([0,.75,2,2.75] if bar%2==0 else [0,1.75,2.5,3.5])
        for step in ks:
            n(0,b+step,[31,28,35][i],[.30,.38,.20][i],114 if step%2==0 else 105)
            n(1,b+step,[76,69,84][i],.025,82)
        for step in [1,3]:
            n(2,b+step,[50,45,56][i],[.12,.08,.11][i],98)
            n(3,b+step,[70,65,78][i],.14,100)
            if i==1:
                for dt in [.026,.052]:n(3,b+step+dt,65,.04,52)
        if i==2:
            for step in [1.5,2.75,3.75]:n(3,b+step,74,.04,42 if step<3 else 57)
        for j in range(16 if i==2 else 8):
            n(4,b+j/(4 if i==2 else 2),[88,78,94][i]+j%2,.035,
              (52 if j%2==0 else 70) if i==2 else (63 if j%2==0 else 82))
        if not thin:
            for step in [.5,1.5,2.5,3.5]:n(5,b+step,[79,70,86][i],.15,77)
        patterns=[[(0,0,.3),(.75,0,.24),(1.5,0,.28),(2,0,.3),(2.75,7,.22),(3.5,0,.25)],
                  [(0,0,.42),(.75,0,.23),(1.5,0,.3),(2.5,0,.38),(3.25,7 if bar%2 else 0,.25)],
                  [(0,0,.4),(.75,0,.22),(1.75,7,.25),(2.5,0,.35),(3.25,0,.3)]]
        for j,(step,p,d) in enumerate(patterns[i]):
            if phrase in [7,15] and j==len(patterns[i])-1:p=2 if i==1 else -2
            n(7,b+step,root+p,d,100 if j%2==0 else 88)
            n(6,b+step,root-12,d+.025,103)
        if not thin and bar%2==0:
            for step in [.5,2.75]:
                for p in [12,19]:n(8,b+step,root+p,.18,80)
        if bar%2==0 and section in [0,1,3,4] and phrase>=8:
            for step,p,d in melodies[i]:
                # Later restatements only change the final answer, preserving identity.
                if section>=3 and step>=6:p+=2
                n(9,b+step,root+p,d,86)
        if phrase in [6,14] and not thin:
            for j,p in enumerate([24,31,29,24]):n(10,b+2+j*.5,root+p,.13,62)
        if phrase in [7,15]:
            for j in range(4):n(3,b+3+j*.25,[70,65,78][i],.06,59+j*8)
            n(11,b+3.5,[64,52,75][i],.08,66)
    return s


def main():
    OUT.mkdir(parents=True,exist_ok=True);catalog=[]
    for i in range(3):
        s=build(i);folder=OUT/s['id'];folder.mkdir(exist_ok=True)
        for t in s['tracks']:
            assert t['notes']
            assert all(0<=b<320 and 0<=p<=127 and d>0 and 0<v<=127 for b,p,d,v in t['notes'])
        for t in s['tracks'][6:11]:assert t['patch'].get('bend',0)==0
        raw=json.dumps(s,indent=2)
        (folder/'score.json').write_text(raw,encoding='utf-8')
        (folder/'score.lua').write_text('return '+lua(s),encoding='utf-8')
        write_midi(s,folder/(s['id']+'.mid'))
        c={k:v for k,v in s.items() if k!='tracks'}
        c['score_sha256']=hashlib.sha256(raw.encode()).hexdigest();catalog.append(c)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua(catalog),encoding='utf-8')
    print('\n'.join(f"{c['id']}: {c['seconds']:.1f}s" for c in catalog))


if __name__=='__main__':main()
