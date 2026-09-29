"""Deterministic boss-only cues. Does not rewrite the selected player effects."""
from array import array
from pathlib import Path
import math
import random
import wave

RATE = 48000
OUT = Path(__file__).resolve().parents[1] / "assets/audio"
TAU = math.tau

def render(name, duration, kind):
    rng = random.Random(8201)
    count = round(RATE * duration)
    pcm = array("h")
    noise = 0.0
    for i in range(count):
        t = i / RATE
        u = i / count
        noise += (rng.uniform(-1, 1) - noise) * 0.09
        if kind == "beam":
            # All oscillators complete integer cycles: a click-free one-second
            # loop, with no random noise or envelope discontinuity at its seam.
            value = (0.25 * math.sin(TAU*96*t + 1.4*math.sin(TAU*192*t))
                     + 0.12 * math.sin(TAU*288*t + 0.7*math.sin(TAU*31*t))
                     + 0.06 * math.sin(TAU*768*t)) * (0.8+0.2*math.cos(TAU*7*t))
            left = value * (0.97+0.03*math.sin(TAU*3*t))
            right = value * (0.97-0.03*math.sin(TAU*3*t))
        else:
            edge = min(1.0, t/0.018, (duration-t)/0.055)
            if kind == "charge":
                phase = TAU*(180*t + 340*t*t/(2*duration))
                value = (0.27*math.sin(phase+1.1*math.sin(phase*2))
                         + 0.08*noise) * (0.3+0.7*u) * (0.7+0.3*math.sin(TAU*(5*t+4*t*t)))
            elif kind == "orb":
                phase = TAU*(72*t + 160*t*t/(2*duration))
                value = (0.3*math.sin(phase) + 0.1*math.sin(phase*2.02) + 0.12*noise) * (0.4+0.6*u)
            elif kind == "mark":
                pulse = math.exp(-((t % 0.25)/0.065)**2)
                value = 0.28*math.sin(TAU*(720 if t < 0.25 else 960)*t)*pulse + 0.055*math.sin(TAU*144*t)*(1-u)
            else:
                phase = TAU*(55*t+180*0.045*(1-math.exp(-t/0.045)))
                value = (0.46*math.sin(phase)+0.38*noise)*math.exp(-5*t)
            left = right = value * edge
        for sample in (left, right): pcm.append(round(max(-0.85, min(0.85, sample))*32767))
    with wave.open(str(OUT / (name+".wav")), "wb") as output:
        output.setparams((2,2,RATE,0,"NONE","not compressed"))
        output.writeframes(pcm.tobytes())
    peak = max(abs(x) for x in pcm)/32767
    rms = math.sqrt(sum((x/32767)**2 for x in pcm)/len(pcm))
    print(f"{name}: {duration:.2f}s peak={peak:.3f} RMS={rms:.3f}")

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for spec in [("triad_charge",1.15,"charge"),("triad_beam",1.0,"beam"),
                 ("boss_orb_charge",1.05,"orb"),("boss_mark",0.72,"mark"),("boss_release",0.55,"release")]:
        render(*spec)
