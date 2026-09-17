"""Four 32-bar melody auditions over the same approved LOCKED CURRENT backing."""
import copy
import hashlib
import json
from sample_score import ROOT,lua,write_midi

OUT=ROOT/'docs/audio/candidates/02-melody-v4'
SOURCE=ROOT/'docs/audio/candidates/stage-v3/02_locked_current/score.json'

# Each row is one bar: (offset in beats, semitones above middle C, held beats).
# Eight-bar themes repeat with a short answering cadence, not random mutations.
THEMES=[
 ('a_redline_oath','A / REDLINE OATH','A heroic minor-key theme with a repeated call and a leading-tone return.',[
  [(0,7,1.25),(1.5,12,.75),(2.5,15,.5),(3,14,.75)],
  [(0,12,1.5),(2,7,.5),(3,8,.75)],
  [(0,7,1.25),(1.5,12,.75),(2.5,14,.5),(3,15,.75)],
  [(0,14,1.25),(1.5,10,.75),(2.5,11,.5),(3,12,.75)],
  [(0,15,1.25),(1.5,14,.5),(2.25,12,.75),(3.25,7,.5)],
  [(0,8,1.5),(2,7,.75),(3,5,.75)],
  [(0,3,.75),(1,5,.75),(2,7,.75),(3,11,.75)],
  [(0,12,2.5),(3,7,.65)],
 ]),
 ('b_neon_pursuit','B / NEON PURSUIT','A driving repeated hook, syncopated answers and a clipped minor-scale descent.',[
  [(0,7,.45),(.75,7,.45),(1.5,10,.75),(2.75,7,.45),(3.5,5,.35)],
  [(0,3,1.25),(1.5,5,.45),(2.25,7,1.25)],
  [(0,7,.45),(.75,7,.45),(1.5,12,.75),(2.75,10,.45),(3.5,7,.35)],
  [(0,5,1.25),(1.5,3,.45),(2.25,2,.65),(3.25,0,.5)],
  [(0,7,.45),(.75,7,.45),(1.5,10,.75),(2.75,7,.45),(3.5,5,.35)],
  [(0,8,1.25),(1.5,7,.45),(2.25,5,1.25)],
  [(0,3,.65),(.75,5,.65),(1.5,7,.65),(2.5,5,.45),(3.25,2,.5)],
  [(0,0,1.5),(2.25,7,.45),(3,7,.65)],
 ]),
 ('c_last_resolve','C / LAST RESOLVE','A more emotional game-theme arc, with a rising call and a firm minor-key answer.',[
  [(0,0,.75),(1,3,.75),(2,7,1.5)],
  [(0,10,1.25),(1.5,8,.75),(2.5,7,1.25)],
  [(0,0,.75),(1,3,.75),(2,7,.65),(3,12,.75)],
  [(0,10,1.25),(1.5,7,.75),(2.5,5,1.25)],
  [(0,8,.75),(1,10,.75),(2,12,1.5)],
  [(0,15,.75),(1,14,.75),(2,12,1.5)],
  [(0,10,.75),(1,8,.75),(2,7,.65),(3,5,.75)],
  [(0,3,1.25),(1.5,2,.65),(2.5,0,1.25)],
 ]),
 ('d_night_signal','D / NIGHT SIGNAL','A tense Phrygian hook: repeated tonic, narrow semitone turns and a rising middle phrase.',[
  [(0,12,.65),(1,12,.45),(1.75,13,.65),(2.75,12,.9)],
  [(0,7,1.25),(1.5,8,.65),(2.5,7,1.0)],
  [(0,12,.65),(1,12,.45),(1.75,15,.65),(2.75,13,.9)],
  [(0,12,1.5),(2,7,.65),(3,5,.75)],
  [(0,3,.65),(1,5,.65),(2,7,1.5)],
  [(0,8,.75),(1.25,10,.75),(2.5,12,1.25)],
  [(0,15,.65),(1,13,.65),(2,12,.65),(3,7,.75)],
  [(0,13,1.25),(1.5,12,2.0)],
 ]),
]


def main():
    base=json.loads(SOURCE.read_text());OUT.mkdir(parents=True,exist_ok=True)
    catalog=[]
    for index,(id,title,description,theme) in enumerate(THEMES):
        s=copy.deepcopy(base)
        s.update(id=id,title=title,description=description,bars=32,seconds=32*240/base['bpm'],role='stage')
        for t in s['tracks']:
            t['notes']=[n for n in t['notes'] if n[0]<128]
            for n in t['notes']:n[2]=min(n[2],128-n[0])
        lead=s['tracks'][9];lead['notes']=[];lead['name']='10 Main melody'
        lead['level_db']=-23
        lead['patch'].update(bend=0,attack=.003,decay=.20,sustain=.55,release=.035,filter=4000,top=-5)
        # Identical accompaniment, synth settings and intro in all four auditions.
        for section in range(3):
            for bar,notes in enumerate(theme):
                row=notes
                if section==1 and bar in [6,7]:
                    answers=[
                      [[(0,7,.75),(1,8,.75),(2,10,.75),(3,11,.75)],[(0,12,1.5),(2,14,.65),(3,12,.75)]],
                      [[(0,10,.65),(.75,7,.65),(1.5,5,.65),(2.5,3,.45),(3.25,2,.5)],[(0,0,2),(2.75,5,.45),(3.5,7,.35)]],
                      [[(0,8,.75),(1,7,.75),(2,5,.65),(3,2,.75)],[(0,3,1.25),(1.5,7,.65),(2.5,12,1.25)]],
                      [[(0,15,.65),(1,13,.65),(2,12,.65),(3,10,.75)],[(0,8,1.25),(1.5,7,2.0)]],
                    ]
                    row=answers[index][bar-6]
                for beat,p,d in row:
                    onset=(8+section*8+bar)*4+beat
                    lead['notes'].append([onset,60+p,d,94 if beat==0 else 87])
        for t in s['tracks']:
            assert all(0<=b<128 and 0<=p<=127 and 0<d<=128-b and 0<v<=127 for b,p,d,v in t['notes'])
        # Intro contains no lead; backing notes and instrument patches are exact
        # source copies, so the preferred opening is not recomposed.
        assert min(n[0] for n in lead['notes'])>=32
        folder=OUT/id;folder.mkdir(exist_ok=True);raw=json.dumps(s,indent=2)
        (folder/'score.json').write_text(raw,encoding='utf-8')
        (folder/'score.lua').write_text('return '+lua(s),encoding='utf-8')
        write_midi(s,folder/(id+'.mid'))
        meta={k:v for k,v in s.items() if k!='tracks'}
        meta['score_sha256']=hashlib.sha256(raw.encode()).hexdigest();catalog.append(meta)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua(catalog),encoding='utf-8')
    print('Four 46.8-second auditions: 8-bar intro, theme, answer, return.')


if __name__=='__main__':main()
