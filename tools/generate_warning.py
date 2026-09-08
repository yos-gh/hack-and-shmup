"""Original two-pulse time warning. Regenerates only warning.wav (PCM, mono)."""
import math
import struct
import wave
from pathlib import Path

rate = 22050
samples = []
for index in range(round(rate * 0.16)):
    time = index / rate
    pulse_start = 0.0 if time < 0.08 else 0.09
    local = time - pulse_start
    if 0 <= local < 0.055:
        envelope = min(1.0, local / 0.004, (0.055 - local) / 0.012)
        frequency = 880 if pulse_start == 0 else 1100
        value = 0.22 * envelope * math.sin(math.tau * frequency * local)
    else:
        value = 0.0
    samples.append(round(value * 32767))
path = Path(__file__).resolve().parents[1] / 'assets/audio/warning.wav'
with wave.open(str(path), 'wb') as output:
    output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
print(path)
