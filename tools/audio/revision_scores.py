"""Second listening round: selected grooves, restrained harmonic layers, boss studies."""
import copy
import hashlib
import json
from candidate_scores import CATALOG, stage, title, ROOT
from sample_score import lua, write_midi

OUT=ROOT/'docs/audio/candidates/underground-v2'


def layer(s,name,voice,level,pan,patch,echo=None):
    t=dict(name=name,voice=voice,level_db=level,pan=pan,patch=patch,echo=echo or False,notes=[])
    s['tracks'].append(t)
    return t['notes']


def note(s,t,b,p,d,v):
    if b<s['bars']*4:
        t.append([round(b,6),p,round(min(d,s['bars']*4-b),6),v])


def atmosphere(s,kind):
    quiet=s['role']=='title'
    pad=layer(s,'12 Veiled strings','stab',-32 if quiet else -31,-.3,
        dict(attack=.24 if not quiet else .5,decay=.8,sustain=.48,release=.65,
             duty=.5,filter=2400,top=-14,bend=0),
        dict(time=60000/s['bpm']*.75,wet=-17,feedback=-12,cutoff=2700,highpass=650))
    air=layer(s,'13 Distant fifth','sub',-31 if quiet else -33,.32,
        dict(attack=.35,decay=.9,sustain=.5,release=.8,bend=0))
    phrase=layer(s,'14 Thread of melody','lead',-32 if quiet else -30,.14,
        dict(attack=.045,decay=.32,sustain=.35,release=.18,duty=1,bend=0,filter=3100,top=-12),
        dict(time=60000/s['bpm']*.75,wet=-13,feedback=-10,cutoff=3000,highpass=750))
    colors={
      'warehouse':[[24,31,38],[24,27,34],[22,29,36],[24,31,37]],
      'acid':[[24,31,37],[25,32,39],[24,27,34],[24,31,37]],
      'breaks':[[24,27,34],[22,29,34],[24,31,38],[25,32,39]],
      'siege':[[24,31,36],[24,25,31],[22,29,34],[24,31,36]],
      'hunter':[[24,25,31],[24,30,37],[22,29,34],[24,31,37]],
      'halo':[[24,31,38],[24,27,34],[25,32,39],[24,31,38]],
      'title':[[24,27,34],[22,29,34],[24,31,38],[24,27,34]],
    }[kind]
    motifs={
      'warehouse':[(0,31,1.4),(2,34,.8),(4.5,32,1.1),(7,31,2.0)],
      'acid':[(.5,36,.8),(2,37,1.2),(4,34,.7),(5.5,31,2)],
      'breaks':[(.75,31,.6),(1.75,34,.5),(3.25,36,1.2),(5.5,34,1),(7,31,.7)],
      'siege':[(0,24,2.2),(3,25,1.0),(5,31,2.5)],
      'hunter':[(.25,36,.5),(1.75,37,.5),(3,31,.7),(4.25,30,.5),(6,31,1.5)],
      'halo':[(0,31,.9),(1.5,34,.9),(3,38,.9),(4.5,37,.9),(6,34,1.3)],
      'title':[(0,31,1.4),(2.5,34,1.2),(5,29,2)],
    }[kind]
    for bar in range(0,s['bars'],4):
        section=bar//16
        # First eight bars establish the existing groove. Layers breathe in/out.
        if bar<8 and not quiet: continue
        if section==2 and bar%16<8 and not quiet: continue
        root=s['root']
        if kind=='breaks' and bar%16>=12: root+=1
        if quiet and (bar//8)%3==2: root-=2
        chord=colors[(bar//4)%4]
        duration=10 if kind in ['hunter','breaks'] else 13
        for interval in chord:
            note(s,pad,bar*4+.25,root+interval,duration,66 if quiet else 72)
        note(s,air,bar*4+.4,root+chord[1],duration+.3,65)
        if bar%16 in [8,12] and section in ([1,2,3] if quiet else [1,3,4,5]):
            for b,p,d in motifs: note(s,phrase,bar*4+b,root+p,d,72)


def evolve_acid(s):
    bass=s['tracks'][7]['notes']; sub=s['tracks'][6]['notes']
    bass.clear(); sub.clear()
    patterns=[
      [(0,0,.22),(.5,12,.15),(.75,1,.25),(1.5,7,.25),(2,0,.3),(2.75,12,.2),(3.25,1,.17),(3.75,0,.16)],
      [(0,0,.35),(.75,7,.18),(1.25,12,.35),(2,1,.18),(2.5,0,.4),(3.25,13,.18),(3.5,12,.18)],
      [(0,0,.65),(1,1,.2),(1.75,7,.4),(2.5,12,.5),(3.25,10,.18),(3.75,7,.18)],
      [(0,0,.2),(.5,7,.2),(1,12,.2),(1.5,13,.2),(2,12,.32),(2.75,7,.22),(3.25,1,.18),(3.5,0,.32)],
      [(0,0,.42),(.75,1,.16),(1.25,12,.17),(1.75,7,.25),(2.5,0,.42),(3.25,-2,.18),(3.75,0,.16)],
    ]
    for bar in range(s['bars']):
        section=bar//16; local=bar%16
        pi=([0,1,2,3,4][section%5]+(1 if local>=8 else 0))%5
        for j,(b,p,d) in enumerate(patterns[pi]):
            if local%8==7 and b>=3:p=[7,1,0][j%3]
            note(s,bass,bar*4+b,s['root']+p,d,101 if j%3==0 else 79)
            if p<7:note(s,sub,bar*4+b,s['root']-12+(p if p<2 else 0),d+.04,99)
        if local in [7,15]:
            note(s,bass,bar*4+3.875,s['root']+12,.08,60)


def boss(index):
    s=stage(CATALOG[5]); kinds=['siege','hunter','halo']; kind=kinds[index]
    s.update(id=['b1_siege_pressure','b2_vector_pursuit','b3_halo_ritual'][index],
             title=['SIEGE PRESSURE','VECTOR PURSUIT','HALO RITUAL'][index],
             role='stage', intended_role='boss',bpm=[168,176,172][index],
             description=['Boss study: crushing half-time accents and a slow warning-string motif.',
             'Boss study: displaced kicks, stalking bass and a sharp answering melody.',
             'Boss study: revolving triplet figures, suspended chip strings and circular tension.'][index])
    s['seconds']=s['bars']*240/s['bpm']
    for ix in [0,1,6,7,9,10]:s['tracks'][ix]['notes']=[]
    if index==0:
        for ix in [2,3]:s['tracks'][ix]['notes']=[n for n in s['tracks'][ix]['notes'] if n[0]%4>=2.9]
    for bar in range(s['bars']):
        b=bar*4; sec=bar//16
        kicks=([0,1,2,3] if index==0 else ([0,.75,2,2.75] if bar%2==0 else [0,1.5,2.5,3.5])) if index<2 else [0,1,2,3]
        for t in kicks:
            note(s,s['tracks'][0]['notes'],b+t,30,.31,114)
            note(s,s['tracks'][1]['notes'],b+t,75,.024,85)
        patterns=[[(0,0,.5),(.75,0,.22),(1.5,1,.22),(2,0,.5),(3,7,.24),(3.5,0,.24)],
                  [(0,0,.2),(.75,12,.2),(1.25,1,.16),(1.75,0,.3),(2.5,7,.25),(3.25,12,.2)],
                  [(0,0,.3),(2/3,7,.24),(4/3,12,.24),(2,0,.3),(8/3,1,.24),(10/3,7,.24)]]
        for t,p,d in patterns[index]:
            if sec>=3 and bar%8>=4:p=12 if p==7 else p
            note(s,s['tracks'][7]['notes'],b+t,s['root']+p,d,95)
            if p<7:note(s,s['tracks'][6]['notes'],b+t,s['root']-12+p,d+.07,105)
        if bar%8>=6:
            for j in range(3 if index==2 else 4):
                note(s,s['tracks'][10]['notes'],b+2+j*(2/3 if index==2 else .5),58+j*3,.06,72)
        if bar>=16 and bar%8 in [4,6]:
            for j,p in enumerate([[12,13,7],[24,25,19],[19,22,26]][index]):
                note(s,s['tracks'][9]['notes'],b+j*.75,s['root']+p,.25,68)
    atmosphere(s,kind)
    return s


def main():
    OUT.mkdir(parents=True,exist_ok=True); scores=[]
    for i,kind in enumerate(['warehouse','acid','breaks']):
        s=stage(CATALOG[i]); s['id']+='_v2';s['title']+=' / V2'
        s['description']=['Original warehouse groove with a thin suspended string layer and sparse answering melody.',
          'Five evolving bass phrases, longer held notes and new turnarounds beneath veiled minor chords.',
          'Original breakbeat retained, with a drifting upper melody and restrained chip-string chords.'][i]
        if i==1:evolve_acid(s)
        atmosphere(s,kind);scores.append(s)
    scores += [boss(i) for i in range(3)]
    s=title(CATALOG[9]);s['id']+='_v2';s['title']+=' / V2'
    s['description']='Original submerged title pulse with a faint sustained upper chord and a distant melodic reply.'
    atmosphere(s,'title');scores.append(s)
    catalog=[]
    for s in scores:
        folder=OUT/s['id'];folder.mkdir(exist_ok=True)
        for t in s['tracks']:
            assert t['notes'],t['name']
            assert all(0<=n[0]<s['bars']*4 and 0<=n[1]<=127 and n[2]>0 and 0<n[3]<=127 for n in t['notes'])
        text=json.dumps(s,indent=2)
        (folder/'score.json').write_text(text,encoding='utf-8')
        (folder/'score.lua').write_text('return '+lua(s),encoding='utf-8')
        write_midi(s,folder/(s['id']+'.mid'))
        c={k:v for k,v in s.items() if k!='tracks'}
        c['score_sha256']=hashlib.sha256(text.encode()).hexdigest();catalog.append(c)
    (OUT/'catalog.json').write_text(json.dumps(catalog,indent=2),encoding='utf-8')
    (OUT/'catalog.lua').write_text('return '+lua(catalog),encoding='utf-8')
    print('\n'.join(f"{c['id']}: {c['seconds']:.1f}s" for c in catalog))


if __name__=='__main__':main()
