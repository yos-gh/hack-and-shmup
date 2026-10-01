"""Chiptune sound effects in the style of a 2A03 sound driver. Standard library only.

Every effect is built from pulse, triangle and LFSR noise voices whose volume
(4-bit), pitch (11-bit period) and duty are updated on a 240 Hz driver tick,
then normalised to one short-term loudness so the mix lives in sound.gd.

    python tools/generate_sfx.py [--out DIR] [--only key,key]
"""
from array import array
from pathlib import Path
import argparse, math, random, wave

RATE = 48000
TICK = 1 / 240
CPU = 1789773
NOISE_PERIODS = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
OUT = Path(__file__).resolve().parents[1] / 'assets/audio'
TARGET_DB = -16.0  # Loudest 50 ms RMS of every effect; sound.gd MIX sets the balance.
PEAK = 10 ** (-1.0 / 20)


def line(*points):
    """Piecewise-linear envelope from (time, value) pairs; holds the ends."""
    def f(t):
        if t <= points[0][0]: return points[0][1]
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t <= t1: return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
        return points[-1][1]
    return f


def glide(f0, f1, duration):
    """Exponential pitch glide, the usual shape of a sweep unit."""
    return lambda t: f0 * (f1 / f0) ** min(1.0, t / duration)


def decay(level, duration, hold=0.0):
    return lambda t: level if t < hold else level * max(0.0, 1 - (t - hold) / (duration - hold))


def const(value):
    return lambda t: value


def pulse(start, length, freq, vol, duty=0.5, gain=1.0, quantize=True):
    return dict(kind='pulse', start=start, length=length, freq=freq, vol=vol,
                duty=duty if callable(duty) else const(duty), gain=gain, quantize=quantize)


def tri(start, length, freq, vol=const(1.0), gain=1.0, quantize=True):
    return dict(kind='tri', start=start, length=length, freq=freq, vol=vol, gain=gain, quantize=quantize)


def noise(start, length, period, vol, short=False, gain=1.0):
    return dict(kind='noise', start=start, length=length, period=period if callable(period) else const(period),
                vol=vol, short=short, gain=gain)


def period_freq(f, divider):
    p = max(8, min(2047, round(CPU / (divider * f) - 1)))
    return CPU / (divider * (p + 1))


def blep(t, dt):
    if t < dt:
        t /= dt
        return t + t - t * t - 1
    if t > 1 - dt:
        t = (t - 1) / dt
        return t * t + t + t + 1
    return 0.0


def render_voice(v, out, seed):
    first = round(v['start'] * RATE)
    count = min(round(v['length'] * RATE), len(out) - first)
    ticks = max(1, round(TICK * RATE))
    phase, level, lfsr, clock = 0.0, 0.0, 1, 0.0
    rng = random.Random(seed)
    lfsr = rng.randrange(1, 1 << 15)
    for j in range(count):
        if j % ticks == 0:
            t = j / RATE
            target = round(max(0.0, min(1.0, v['vol'](t))) * 15) / 15
            if v['kind'] == 'noise':
                rate = CPU / NOISE_PERIODS[max(0, min(15, round(v['period'](t))))] / RATE
            else:
                f = v['freq'](t)
                if v['quantize']: f = period_freq(f, 16 if v['kind'] == 'pulse' else 32)
                dt = f / RATE
                if v['kind'] == 'pulse': duty = v['duty'](t)
        level += (target - level) * 0.02  # ~1 ms DAC slew keeps tick steps from clicking.
        if v['kind'] == 'pulse':
            value = 1.0 if phase < duty else -1.0
            value += blep(phase, dt) - blep((phase - duty) % 1.0, dt)
            phase = (phase + dt) % 1.0
        elif v['kind'] == 'tri':
            step = int(phase * 32)
            value = ((15 - step) if step < 16 else (step - 16)) / 7.5 - 1
            phase = (phase + dt) % 1.0
        else:
            clock += rate
            total, n = 0.0, 0
            while clock >= 1:
                clock -= 1
                feedback = (lfsr ^ (lfsr >> (6 if v['short'] else 1))) & 1
                lfsr = (lfsr >> 1) | (feedback << 14)
                total += 1.0 if lfsr & 1 else -1.0
                n += 1
            value = total / n if n else (1.0 if lfsr & 1 else -1.0)
        out[first + j] += value * level * v['gain']


def render(spec, seed):
    out = [0.0] * round(spec['length'] * RATE)
    for i, voice in enumerate(spec['voices']):
        render_voice(voice, out, seed * 31 + i)
    # Output stage: DC/body high-pass per effect, then a soft low-pass (12 kHz unless muffled).
    hp = math.exp(-math.tau * spec.get('hp', 60) / RATE)
    lp = 1 - math.exp(-math.tau * spec.get('lp', 12000) / RATE)
    x1 = y1 = z = z2 = 0.0
    for i, x in enumerate(out):
        y1 = hp * (y1 + x - x1)
        x1 = x
        z += (y1 - z) * lp
        z2 += (z - z2) * lp
        out[i] = z2 if 'lp' in spec else z
    fade = min(len(out), round(0.004 * RATE))
    for i in range(fade): out[-1 - i] *= i / fade
    return out


def short_term_db(data):
    window = round(0.05 * RATE)
    best = 1e-9
    for start in range(0, max(1, len(data) - window + 1), window // 4):
        chunk = data[start:start + window]
        best = max(best, math.sqrt(sum(x * x for x in chunk) / len(chunk)))
    return 20 * math.log10(best)


def save(path, data):
    gain = 10 ** ((TARGET_DB - short_term_db(data)) / 20)
    peak = max(abs(x) for x in data) * gain
    if peak > PEAK: gain *= PEAK / peak
    pcm = array('h')
    for x in data:
        s = int(round(max(-1.0, min(1.0, x * gain)) * 32767))
        pcm.extend((s, s))
    with wave.open(str(path), 'wb') as w:
        w.setparams((2, 2, RATE, 0, 'NONE', 'not compressed'))
        w.writeframes(pcm.tobytes())
    return short_term_db([x * gain for x in data]), 20 * math.log10(max(abs(x) for x in data) * gain)


def note(n):
    return 440 * 2 ** ((n - 69) / 12)


def vibrato(base, rate, depth):
    return lambda t: base(t) * (1 + depth * math.sin(math.tau * rate * t))


def alternate(a, b, period):
    return lambda t: a if int(t / period) % 2 == 0 else b


def steps(values, period, hold_last=True):
    return lambda t: values[min(len(values) - 1, int(t / period))] if hold_last else values[int(t / period) % len(values)]


def seq(notes, period, duty=0.25, gain=1.0, level=0.9, tail=0.0, start=0.0, offset=0):
    """A run of short driver notes, each with its own 4-bit decay."""
    voices = []
    for i, n in enumerate(notes):
        if n is None: continue
        length = period if i < len(notes) - 1 else period + tail
        voices.append(pulse(start + i * period, length, const(note(n + offset)), decay(level, length), duty, gain))
    return voices


EFFECTS = {
    # Player weapons -------------------------------------------------------
    # Thin 12.5% blip with a bright noise tick; short enough to retrigger cleanly at any fire rate.
    'shot': dict(length=0.055, hp=520, voices=[
        pulse(0, 0.055, line((0, 1900), (0.010, 1180), (0.055, 860)), line((0, 0.85), (0.012, 0.55), (0.055, 0)), 0.125),
        noise(0, 0.018, 2, decay(0.55, 0.018)),
    ]),
    'scatter': dict(length=0.22, hp=140, voices=[
        noise(0, 0.22, line((0, 4), (0.2, 10)), line((0, 1), (0.03, 0.75), (0.22, 0))),
        pulse(0, 0.13, glide(560, 130, 0.13), decay(0.65, 0.13), 0.25, 0.8),
        tri(0, 0.09, glide(140, 60, 0.09), decay(1, 0.09), 0.9),
    ]),
    'shock': dict(length=0.46, hp=55, voices=[
        tri(0, 0.38, glide(240, 50, 0.34), decay(1, 0.38), 1.0),
        pulse(0, 0.42, vibrato(glide(340, 75, 0.4), 17, 0.06), decay(0.8, 0.42, 0.04), alternate(0.125, 0.25, TICK * 2), 0.6),
        noise(0, 0.32, line((0, 5), (0.3, 12)), decay(0.7, 0.32)),
    ]),
    'lance': dict(length=0.34, hp=160, voices=[
        pulse(0, 0.34, lambda t: [note(69), note(81), note(88)][int(t / 0.012)] if t < 0.036 else note(93) * (1 + 0.03 * math.sin(math.tau * 32 * t)),
              line((0, 1), (0.14, 0.85), (0.34, 0)), line((0, 0.5), (0.2, 0.125)), 0.8),
        pulse(0, 0.30, lambda t: note(81) * (1 + 0.03 * math.sin(math.tau * 32 * t + 1)), line((0, 0.6), (0.3, 0)), 0.25, 0.45),
        noise(0, 0.07, 2, decay(0.6, 0.07), short=True),
    ]),
    # Impacts --------------------------------------------------------------
    'hit': dict(length=0.05, hp=220, voices=[
        noise(0, 0.035, 5, decay(0.9, 0.035)),
        pulse(0, 0.05, glide(320, 170, 0.05), decay(0.6, 0.05), 0.25),
    ]),
    'kill': dict(length=0.24, hp=80, voices=[
        noise(0, 0.24, line((0, 6), (0.22, 11)), line((0, 1), (0.04, 0.8), (0.24, 0))),
        pulse(0, 0.13, glide(420, 85, 0.13), decay(0.7, 0.13), 0.5, 0.8),
    ]),
    # Shield enemy's front: an inharmonic clank, low enough not to ping.
    'shield': dict(length=0.08, hp=300, voices=[
        pulse(0, 0.075, const(960), decay(0.8, 0.075), 0.125),
        pulse(0, 0.05, const(1360), decay(0.6, 0.05), 0.125, 0.8),
        noise(0, 0.02, 4, decay(0.6, 0.02), short=True),
    ]),
    # Boss plates and turrets absorb shots with a dull knock.
    'armor': dict(length=0.045, hp=150, voices=[
        noise(0, 0.03, 8, decay(0.8, 0.03)),
        tri(0, 0.045, glide(170, 100, 0.045), decay(1, 0.045)),
    ]),
    'armor_break': dict(length=0.32, hp=90, voices=[
        noise(0, 0.04, 3, decay(0.8, 0.04), short=True),
        noise(0.01, 0.31, line((0, 5), (0.3, 11)), line((0, 1), (0.31, 0))),
        pulse(0, 0.22, glide(820, 110, 0.22), decay(0.7, 0.22), 0.125, 0.8),
    ]),
    # Player outcome ------------------------------------------------------
    'death': dict(length=0.72, hp=40, voices=[
        noise(0, 0.72, line((0, 8), (0.7, 14)), line((0, 1), (0.08, 0.9), (0.72, 0))),
        pulse(0, 0.5, glide(640, 55, 0.5), decay(0.75, 0.5), alternate(0.5, 0.25, TICK * 3), 0.8),
        tri(0, 0.42, glide(95, 38, 0.4), decay(1, 0.42)),
    ]),
    'timeout': dict(length=0.72, hp=70, voices=[
        pulse(0, 0.24, const(note(67)), line((0, 0.9), (0.2, 0.8), (0.24, 0)), 0.5),
        pulse(0.3, 0.42, const(note(60)), line((0, 0.9), (0.2, 0.8), (0.42, 0)), 0.5),
        pulse(0, 0.24, const(note(55)), line((0, 0.5), (0.24, 0)), 0.25, 0.6),
        pulse(0.3, 0.42, const(note(48)), line((0, 0.5), (0.42, 0)), 0.25, 0.6),
    ]),
    # Checkpoint passed: the rising arpeggio an octave down, slower and muffled.
    'clear': dict(length=0.98, hp=70, lp=2400, voices=[
        *seq([64, 69, 73, 76], 0.085, 0.5, level=0.8),
        pulse(0.34, 0.64, const(note(81)), line((0, 0.8), (0.25, 0.55), (0.64, 0)), 0.5),
        *seq([64, 69, 73, 76], 0.085, 0.25, gain=0.3, level=0.8, start=0.05),
        tri(0, 0.98, steps([note(45), note(45), note(52), note(57)], 0.085), line((0, 0.9), (0.6, 0.9), (0.98, 0))),
    ]),
    'warning': dict(length=0.13, hp=200, voices=[
        pulse(0, 0.13, const(note(84)), line((0, 0.9), (0.1, 0.8), (0.13, 0)), 0.25),
        pulse(0, 0.13, const(note(72)), line((0, 0.5), (0.13, 0)), 0.5, 0.5),
    ]),
    # Enemy fire ----------------------------------------------------------
    'sniper_fire': dict(length=0.11, hp=260, voices=[
        pulse(0, 0.11, glide(2100, 480, 0.09), decay(0.8, 0.11), 0.125),
        noise(0, 0.02, 3, decay(0.6, 0.02), short=True),
    ]),
    'siege_fire': dict(length=0.2, hp=60, voices=[
        tri(0, 0.16, glide(160, 50, 0.14), decay(1, 0.16)),
        noise(0, 0.2, line((0, 8), (0.18, 12)), decay(0.9, 0.2)),
        pulse(0, 0.09, glide(220, 80, 0.09), decay(0.5, 0.09), 0.5, 0.6),
    ]),
    'halo_fire': dict(length=0.2, hp=120, voices=[
        pulse(0, 0.2, vibrato(glide(360, 220, 0.18), 26, 0.05), decay(0.8, 0.2), 0.125),
        pulse(0, 0.16, glide(540, 330, 0.16), decay(0.5, 0.16), 0.25, 0.6),
        noise(0, 0.05, 7, decay(0.5, 0.05)),
    ]),
    'pearl_fire': dict(length=0.1, hp=240, voices=[
        pulse(0, 0.1, glide(560, 380, 0.1), decay(0.7, 0.1), 0.125),
        noise(0, 0.03, 6, decay(0.4, 0.03)),
    ]),
    # Laser warning: a low buzz that climbs, never a chime.
    'hunter_lock': dict(length=0.32, hp=80, voices=[
        pulse(0, 0.32, glide(110, 440, 0.3), line((0, 0.7), (0.26, 0.95), (0.32, 0)), alternate(0.125, 0.5, TICK)),
        pulse(0, 0.32, glide(165, 660, 0.3), line((0, 0.3), (0.26, 0.5), (0.32, 0)), 0.125, 0.5),
        noise(0, 0.3, 10, line((0, 0.2), (0.26, 0.45), (0.3, 0)), short=True, gain=0.6),
    ]),
    'hunter_fire': dict(length=0.3, hp=160, voices=[
        noise(0, 0.3, line((0, 1), (0.28, 5)), line((0, 1), (0.05, 0.8), (0.3, 0)), short=True),
        pulse(0, 0.2, glide(1500, 280, 0.2), decay(0.7, 0.2), 0.125, 0.8),
    ]),
    # Missile target mark: three stern, beating lock pulses.
    'boss_mark': dict(length=0.72, hp=90, voices=[
        v for k in range(3) for v in (
            pulse(k * 0.2, 0.09, const(233), line((0, 0.9), (0.07, 0.8), (0.09, 0)), 0.125),
            pulse(k * 0.2, 0.09, const(247), line((0, 0.6), (0.07, 0.5), (0.09, 0)), 0.125, 0.8),
            noise(k * 0.2, 0.05, 9, decay(0.6, 0.05), short=True, gain=0.6),
        )
    ]),
    'boss_orb_charge': dict(length=1.05, hp=50, voices=[
        tri(0, 1.05, glide(55, 220, 1.0), line((0, 0.6), (0.9, 1), (1.05, 0))),
        pulse(0, 1.05, lambda t: 110 * 4 ** (t / 1.05) * (1 + 0.05 * math.sin(math.tau * (6 * t + 12 * t * t))), line((0, 0.3), (0.95, 0.9), (1.05, 0)), 0.25, 0.7),
        noise(0, 1.05, line((0, 12), (1.0, 6)), line((0, 0), (0.9, 0.5), (1.05, 0)), gain=0.6),
    ]),
    'boss_release': dict(length=0.55, hp=60, voices=[
        noise(0, 0.55, line((0, 4), (0.5, 10)), line((0, 1), (0.1, 0.7), (0.55, 0))),
        tri(0, 0.13, glide(90, 40, 0.12), decay(1, 0.13)),
        pulse(0, 0.25, glide(300, 900, 0.25), decay(0.35, 0.25), 0.125, 0.6),
    ]),
    'triad_charge': dict(length=1.15, hp=60, voices=[
        pulse(0, 1.15, lambda t: note(45) * 4 ** (t / 1.1) * (1.5 if int(t / (TICK * 2)) % 2 else 1), line((0, 0.3), (1.05, 1), (1.15, 0)), 0.5),
        tri(0, 1.15, const(55), line((0, 0.8), (1.05, 1), (1.15, 0))),
        noise(0.5, 0.65, 10, line((0, 0), (0.55, 0.4), (0.65, 0)), short=True, gain=0.5),
    ]),
    # Rendered for 2 s and trimmed to the second half so the loop starts in steady state.
    'triad_beam': dict(length=2.0, hp=50, loop=True, voices=[
        pulse(0, 2.0, const(110), const(0.8), 0.25, quantize=False),
        pulse(0, 2.0, const(165), const(0.5), alternate(0.125, 0.25, 1 / 16), 0.6, quantize=False),
        tri(0, 2.0, const(55), const(1), quantize=False),
        noise(0, 2.0, 9, lambda t: 0.35 + 0.25 * math.sin(math.tau * 8 * t), gain=0.6),
    ]),
    'boss_destroy': dict(length=1.65, hp=35, voices=[
        *[noise(t0, 0.25, line((0, p), (0.2, p + 3)), decay(0.9, 0.25)) for t0, p in [(0, 6), (0.16, 7), (0.32, 5), (0.5, 8)]],
        noise(0.72, 0.93, line((0, 9), (0.9, 15)), line((0, 1), (0.1, 0.95), (0.93, 0))),
        pulse(0, 1.3, glide(900, 40, 1.25), line((0, 0.7), (1.3, 0)), alternate(0.5, 0.125, TICK * 4), 0.7),
        tri(0.7, 0.8, glide(110, 30, 0.7), decay(1, 0.8)),
    ]),
    # Newly voiced events ------------------------------------------------
    'charge': dict(length=0.26, hp=70, voices=[
        pulse(0, 0.26, glide(90, 280, 0.22), line((0, 0.5), (0.18, 0.9), (0.26, 0)), alternate(0.25, 0.5, TICK), 0.9),
        noise(0, 0.26, line((0, 11), (0.22, 7)), line((0, 0.2), (0.18, 0.6), (0.26, 0))),
    ]),
    'warp': dict(length=0.3, hp=150, voices=[
        pulse(0, 0.3, lambda t: 520 * 2 ** (1.5 * t / 0.3) * (2 if int(t / (TICK * 2)) % 2 else 1), line((0, 0.4), (0.2, 0.8), (0.3, 0)), 0.125),
        noise(0, 0.3, 3, line((0, 0), (0.2, 0.35), (0.3, 0)), short=True, gain=0.5),
    ]),
    # The way down unlocks: the same rising fifth-and-octave, low and muffled.
    'stairs': dict(length=0.72, hp=60, lp=2000, voices=[
        *seq([60, 67, 72], 0.1, 0.5, level=0.8, tail=0.42),
        *seq([60, 67, 72], 0.1, 0.25, gain=0.3, level=0.8, tail=0.34, start=0.05),
        tri(0, 0.72, const(note(48)), line((0, 1), (0.45, 0.9), (0.72, 0))),
    ]),
    'arrival': dict(length=0.42, hp=90, voices=[
        noise(0, 0.42, line((0, 3), (0.4, 10)), line((0, 0.1), (0.1, 0.6), (0.42, 0))),
        pulse(0, 0.36, glide(1200, 240, 0.36), line((0, 0.1), (0.08, 0.6), (0.36, 0)), 0.125, 0.7),
    ]),
    'select': dict(length=0.1, hp=200, voices=[
        *seq([83, 88], 0.045, 0.5, level=0.8, tail=0.01),
    ]),
    # Drop item collected: a soft upward fifth, rounded off like the stair cues.
    'pickup': dict(length=0.34, hp=120, lp=2600, voices=[
        *seq([67, 74, 79], 0.055, 0.5, level=0.8, tail=0.18),
        *seq([67, 74, 79], 0.055, 0.25, gain=0.3, level=0.8, tail=0.12, start=0.03),
        tri(0, 0.34, steps([note(55), note(62), note(67)], 0.055), line((0, 0.8), (0.2, 0.7), (0.34, 0))),
    ]),
    # Drop effect runs out: the same interval falling, quieter and shorter.
    'buff_end': dict(length=0.22, hp=150, lp=1800, voices=[
        *seq([74, 67], 0.07, 0.25, level=0.7, tail=0.08),
        tri(0, 0.22, steps([note(62), note(55)], 0.07), line((0, 0.6), (0.22, 0))),
    ]),
    'ready': dict(length=0.07, hp=400, voices=[
        pulse(0, 0.07, const(note(91)), decay(0.6, 0.07), 0.25),
        pulse(0.02, 0.05, const(note(96)), decay(0.4, 0.05), 0.25),
    ]),
}


def build(key, out_dir):
    spec = EFFECTS[key]
    data = render(spec, sum(map(ord, key)))
    if spec.get('loop'): data = data[len(data) // 2:]
    return save(out_dir / (key + '.wav'), data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, default=OUT)
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    keys = [k for k in args.only.split(',') if k] or list(EFFECTS)
    for key in keys:
        loud, peak = build(key, args.out)
        print(f'{key:16s} {EFFECTS[key]["length"]:.3f}s  short-term {loud:6.1f} dB  peak {peak:5.1f} dB')


if __name__ == '__main__':
    main()
