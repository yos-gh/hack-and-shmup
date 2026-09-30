"""Original deterministic chip/club loop (descent.wav). Standard library only; effects are in generate_sfx.py."""
from array import array
from pathlib import Path
import math, random, wave
RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
TAU = math.tau
rng = random.Random(177)
def save(name, data):
    peak = max(abs(x) for x in data) or 1
    gain = min(1, .88 / peak)
    pcm = array('h', (int(max(-1,min(1,x*gain))*32767) for x in data))
    with wave.open(str(OUT / (name+'.wav')), 'wb') as w:
        w.setparams((1,2,RATE,0,'NONE','not compressed')); w.writeframes(pcm.tobytes())
    print(name, 'seconds', round(len(data)/RATE,3), 'peak', round(peak*gain,3))
def freq(note): return 440*2**((note-69)/12)
def add(buf, start, duration, fn, gain):
    first = round(start*RATE); count = round(duration*RATE)
    for j in range(count):
        t=j/RATE
        edge=min(1,j/64,(count-1-j)/128)
        buf[(first+j)%len(buf)] += gain*edge*fn(t)
beat=60/150
# Exactly four 4/4 bars: Am / F / E / Am. No arpeggio phase carries past the loop.
length=4*4*beat
music=array('f',[0])*round(length*RATE)
roots=[33,29,40,33]
phrases=[[69,72,76,72,69,72,76,81], [69,72,77,72,69,65,69,72],
         [68,71,76,71,68,64,68,71], [81,76,72,69,76,72,69,68]]
for bar,root in enumerate(roots):
    for step in range(16):
        start=(bar*16+step)*beat/4
        if step%4==0:
            add(music,start,.23,lambda t: math.sin(TAU*(47*t+75*.025*(1-math.exp(-t/.025))))*math.exp(-t*19),.5)
        if step%8==4 and not (bar==3 and step==12):
            add(music,start,.14,lambda t: (rng.uniform(-1,1)*.8+math.sin(TAU*185*t)*.2)*math.exp(-t*28),.23)
        if step%2==0 and not (bar==3 and step>=12):
            add(music,start,.045,lambda t: rng.uniform(-1,1)*math.exp(-t*90),.09)
        if step in ([0,3,6,8,12] if bar==3 else [0,3,6,8,10,14]):
            f=freq(root)
            add(music,start,.14,lambda t,f=f: (.65*math.sin(TAU*f*t)+.35*(1 if (f*t)%1<.35 else -1))*math.exp(-t*8),.2)
        if step%2==0 and step//2<len(phrases[bar]):
            f=freq(phrases[bar][step//2])
            add(music,start,.14,lambda t,f=f: (1 if (f*t)%1<.25 else -.333)*math.exp(-t*18),.085)
            add(music,start+.1,.14,lambda t,f=f: (1 if (f*t)%1<.25 else -.333)*math.exp(-t*18),.02)
save('descent',music)
