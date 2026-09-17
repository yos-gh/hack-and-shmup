"""Compare native Godot loop capture with independently decoded Ogg samples."""
from array import array
import json
import math
import wave
from pathlib import Path
from prepare_review import measure

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/audio/review'


def read(path):
    with wave.open(str(path)) as stream:
        assert stream.getframerate() == 48000 and stream.getnchannels() == 2
        assert stream.getsampwidth() == 2
        data = array('h', stream.readframes(stream.getnframes()))
    return data


def main():
    native = read(OUT / 'loops.wav')
    reference = read(OUT / 'ogg-reference.wav')
    period = 48000 * 48 * 2
    assert len(reference) == period
    assert len(native) >= period * 3
    # Decoder startup latency is not a musical loop gap. Find it independently.
    _, offset = min((sum(abs(native[shift*2+i]-reference[i])
                        for i in range(200, 30000, 137)), shift)
                    for shift in range(0, 256))
    boundary_errors = []
    for cycle in [1, 2]:
        at = cycle * period
        maximum = max(abs(native[offset*2+at+j]-reference[j % period])
                      for j in range(-2048, 2048))
        boundary_errors.append(maximum)
        assert maximum <= 8, f'Decoded loop boundary differs: {maximum} PCM steps'
    repeat_error = max(abs(native[i+period]-native[i+period*2])
                       for i in range(1024, period-1024, 31))
    assert repeat_error <= 2
    mix = measure(OUT / 'combat.mp4')
    assert math.isfinite(mix['lufs']) and mix['true_peak_db'] <= -1
    for filename in ['smoke.log', 'capture-v2.log', 'loops.log', 'regression.log']:
        text = (OUT / filename).read_text(encoding='utf-8')
        assert 'PASS:' in text, filename
        assert not any(marker in text for marker in ['FAIL:', 'SCRIPT ERROR:', 'ERROR:']), filename
    report = dict(music_seconds=48, rendered_cycles=3, startup_offset_frames=offset,
                  boundary_max_pcm_steps=boundary_errors, repeat_max_pcm_steps=repeat_error,
                  combat=mix, status='PASS', listening_approval='pending')
    (OUT / 'verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
