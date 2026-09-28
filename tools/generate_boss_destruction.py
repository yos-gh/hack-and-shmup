"""Reproducible layered synthetic explosion; edits no other audio assets."""
from array import array
from pathlib import Path
import math
import random
import wave

RATE = 48000
DURATION = 1.65


def render():
    rng = random.Random(290925)
    channels = [[], []]
    low = [0.0, 0.0]
    rumble = [0.0, 0.0]
    for frame in range(round(RATE * DURATION)):
        t = frame / RATE
        # Integrated falling frequency: a solid low impact, not a musical note.
        phase = math.tau * (38*t + 100*0.038*(1-math.exp(-t/0.038)))
        body = 0.70*math.sin(phase)*math.exp(-t/0.22)
        edge = min(1.0, t/0.0025, (DURATION-t)/0.12)
        for channel in range(2):
            noise = rng.uniform(-1, 1)
            low[channel] += 0.16*(noise-low[channel])
            rumble[channel] += 0.025*(noise-rumble[channel])
            blast = 1.6*low[channel]*math.exp(-t/0.30)
            crack = 0.30*noise*math.exp(-t/0.016)
            tail = 1.1*rumble[channel]*math.exp(-t/0.5)
            shards = 0.0
            for index, onset in enumerate([0.065, 0.13, 0.23, 0.36, 0.51]):
                age = t-onset-channel*0.006*(index%2)
                if age < 0: continue
                attack = min(1.0, age/0.003)
                shards += attack*(0.24*low[channel]+0.055*math.sin(math.tau*(890+index*317)*age))*math.exp(-age/(0.055+index*0.013))
            channels[channel].append((body+blast+crack+tail+shards)*edge)
    peak = max(abs(sample) for channel in channels for sample in channel)
    gain = 0.82/peak
    pcm = array('h')
    for left, right in zip(*channels):
        pcm.extend([round(left*gain*32767), round(right*gain*32767)])
    output = Path(__file__).resolve().parents[1]/'assets/audio/boss_destroy.wav'
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), 'wb') as audio:
        audio.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        audio.writeframes(pcm.tobytes())
    rms = math.sqrt(sum((sample/32767)**2 for sample in pcm)/len(pcm))
    print(f'boss_destroy: {DURATION:.2f}s, peak=0.820, RMS={rms:.3f}')


if __name__ == '__main__':
    render()
