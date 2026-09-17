"""Original 32-bar / 48-second chip-rave review score, independent of the synth.

This module describes MIDI notes and sound-design intent. REAPER is responsible
for synthesis and effects. Beat coordinates use quarter notes, not seconds.
"""
from __future__ import annotations

import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BPM = 160
BARS = 32


def make_score():
    tracks = []

    def track(name, voice, level_db, pan=0.0):
        result = dict(name=name, voice=voice, level_db=level_db, pan=pan, notes=[])
        tracks.append(result)
        return result["notes"]

    def note(target, beat, pitch, duration, velocity=100):
        target.append([round(beat, 5), pitch, round(duration, 5), velocity])

    kick = track("01 Kick body", "kick", -9)
    click = track("02 Kick edge", "kick_edge", -26)
    snare = track("03 Snare body", "snare_body", -21)
    noise = track("04 Snare noise", "snare_noise", -17)
    hat = track("05 Closed hats", "hat", -25, 0.16)
    open_hat = track("06 Offbeat hats", "open_hat", -25, -0.16)
    sub = track("07 Triangle foundation", "sub", -14)
    bass = track("08 Pulse bass", "bass", -21)
    stab = track("09 Rave stabs", "stab", -26, -0.22)
    lead = track("10 Broken signal", "lead", -24, 0.10)
    arp = track("11 Clock fragments", "arp", -29, 0.30)
    accent = track("12 Transition sparks", "spark", -28, -0.30)

    # D pedal, Phrygian tension and descending roots; no copied musical phrases.
    roots = [38, 38, 38, 39, 38, 38, 36, 34]
    bass_steps = [0, .75, 1.5, 2, 2.75, 3.5]
    hook = [(0, 74), (.5, 74), (.75, 77), (1.5, 75), (2.25, 69),
            (2.75, 72), (3.25, 75), (3.5, 74)]
    for bar in range(BARS):
        base = bar * 4
        root = roots[bar % 8]
        section = bar // 8
        for beat in range(4):
            if bar % 8 == 7 and beat == 3:
                continue
            note(kick, base + beat, 31, .28, 116 if beat % 2 == 0 else 109)
            note(click, base + beat, 76, .025, 82)
        for beat in [1, 3]:
            note(snare, base + beat, 50, .12, 97)
            note(noise, base + beat, 70, .14, 102)
        for step in range(8):
            note(hat, base + step / 2, 88 + (step % 3), .035,
                 65 if step % 2 == 0 else 84)
        if section != 2 or bar % 2:
            for beat in [.5, 1.5, 2.5, 3.5]:
                note(open_hat, base + beat, 79, .17, 79)
        for j, step in enumerate(bass_steps):
            pitch = root + (12 if j == 4 and bar % 2 else 0)
            note(sub, base + step, pitch - 12, .31, 106)
            note(bass, base + step, pitch, .25, 100 if j % 2 == 0 else 88)
        if section in [0, 2, 3]:
            for step in ([.5, 2.75] if bar % 2 == 0 else [1.75, 3.25]):
                for interval in [12, 19, 24]:
                    note(stab, base + step, root + interval, .16, 84)
        if section in [1, 3] or (section == 2 and bar % 2 == 1):
            for step, pitch in hook:
                altered = pitch + (1 if bar % 8 == 3 else 0)
                if bar % 8 in [6, 7]:
                    altered -= 2
                if section == 3 and step >= 3:
                    altered += 12
                note(lead, base + step, altered, .13 if step % 1 else .22, 88)
        if section in [1, 3] or bar % 4 >= 2:
            seq = [0, 7, 12, 7, 0, 13, 12, 7]
            for step in range(16):
                if section == 0 and step < 8:
                    continue
                note(arp, base + step / 4, root + 24 + seq[step % 8], .085,
                     58 + (step % 4) * 6)
        if bar % 8 == 7:
            for j in range(4):
                note(noise, base + 3 + j / 4, 70, .08, 68 + j * 9)
                note(accent, base + 3 + j / 4, 86 - j * 3, .10, 70 + j * 5)
    return dict(title="BLACK CIRCUIT — review excerpt", bpm=BPM, bars=BARS,
                seconds=BARS * 4 * 60 / BPM, tracks=tracks)


def lua(value):
    if isinstance(value, dict):
        return "{" + ",".join("[" + json.dumps(k) + "]=" + lua(v) for k, v in value.items()) + "}"
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    return json.dumps(value, ensure_ascii=False)


def write_midi(score, path):
    def vlq(n):
        result = [n & 127]
        while n >> 7:
            n >>= 7
            result.insert(0, (n & 127) | 128)
        return bytes(result)

    def chunk(data):
        return b'MTrk' + struct.pack('>I', len(data)) + data

    tempo = round(60_000_000 / score['bpm'])
    parts = [chunk(b'\x00\xff\x51\x03' + tempo.to_bytes(3, 'big') + b'\x00\xff\x2f\x00')]
    for index, track in enumerate(score['tracks']):
        events = []
        channel = index % 16
        for beat, pitch, length, velocity in track['notes']:
            events.extend([(round(beat * 960), bytes([0x90 | channel, pitch, velocity])),
                           (round((beat + length) * 960), bytes([0x80 | channel, pitch, 0]))])
        events.sort(key=lambda event: (event[0], event[1][0]))
        name = track['name'].encode('ascii')
        data = b'\x00\xff\x03' + vlq(len(name)) + name
        last = 0
        for tick, event in events:
            data += vlq(tick - last) + event
            last = tick
        parts.append(chunk(data + b'\x00\xff\x2f\x00'))
    path.write_bytes(b'MThd' + struct.pack('>IHHH', 6, 1, len(parts), 960) + b''.join(parts))


if __name__ == "__main__":
    score = make_score()
    destination = ROOT / "docs/audio/sample"
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "score.json").write_text(json.dumps(score, indent=2), encoding="utf-8")
    (destination / "score.lua").write_text("return " + lua(score), encoding="utf-8")
    write_midi(score, destination / "black_circuit.mid")
    print(f"Score prepared: {len(score['tracks'])} tracks, {score['seconds']:.0f} seconds")
