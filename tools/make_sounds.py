"""Generates the short sound effects and the music loop (original, synthesised)."""
import math, struct, wave, pathlib
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets/audio"
SR = 22050

def note(f, dur, vol=0.5, kind="sine", attack=0.005, decay=None):
    n = int(SR * dur); out = []
    decay = decay or dur
    for i in range(n):
        t = i / SR
        env = min(1, t / attack) * math.exp(-3.2 * t / decay)
        ph = 2 * math.pi * f * t
        if kind == "sine": v = math.sin(ph)
        elif kind == "soft": v = math.sin(ph) + 0.3 * math.sin(2 * ph) + 0.1 * math.sin(3 * ph)
        else: v = (1 if math.sin(ph) > 0 else -1) * 0.5
        out.append(v * env * vol)
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks); o = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t): o[i] += v
    return o

def seq(items, gap=0.0):
    out = []
    for s in items:
        out += s + [0.0] * int(SR * gap)
    return out

def offset(track, sec):
    return [0.0] * int(SR * sec) + track

def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    k = min(1.0, 0.9 / peak)
    with wave.open(str(OUT / name), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples))

C5, D5, E5, G5, A5, C6, E6 = 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1318.5
save("tap.wav", note(900, 0.05, 0.4, "soft", decay=0.05))
save("send.wav", seq([note(520, 0.06, .4, "soft"), note(780, 0.09, .4, "soft")]))
save("cold.wav", seq([note(330, 0.1, .4, "soft"), note(262, 0.16, .4, "soft")]))
save("warm.wav", seq([note(440, 0.09, .4, "soft"), note(523, 0.14, .4, "soft")]))
save("hot.wav", seq([note(659, 0.08, .4, "soft"), note(880, 0.08, .4, "soft"), note(1175, 0.2, .4, "soft")]))
save("tick.wav", note(700, 0.07, .5, "sine", decay=0.06))
save("go.wav", mix(note(880, 0.35, .5, "soft"), note(1320, 0.35, .3, "soft")))
save("lose.wav", seq([note(392, 0.18, .45, "soft"), note(349, 0.18, .45, "soft"), note(294, 0.4, .45, "soft")]))
fan = seq([note(f, 0.13, .45, "soft") for f in (C5, E5, G5, C6)])
chord = mix(note(C5, 0.9, .35, "soft"), note(E5, 0.9, .35, "soft"), note(G5, 0.9, .35, "soft"), note(C6, 0.9, .35, "soft"))
save("win.wav", fan + chord)
save("coin.wav", seq([note(1318, 0.07, .4, "soft"), note(1760, 0.2, .4, "soft")]))

# Music: calm, 4-chord loop with a soft arpeggio (~21 s).
chords = [(261.6, 329.6, 392.0), (220.0, 261.6, 329.6), (174.6, 220.0, 261.6), (196.0, 246.9, 293.7)]
beat = 0.42
track = []
for _ in range(2):
    for c in chords:
        bar = []
        for i in range(8):
            f = c[i % 3] * (2 if i % 4 == 3 else 1)
            bar += note(f, beat, 0.30, "soft", decay=beat * 1.6)
        pad = mix(*[note(f / 2, beat * 8, 0.10, "soft", attack=0.2, decay=beat * 12) for f in c])
        track += mix(bar, pad[:len(bar)])
# fade ends so the loop is seamless
fade = int(SR * 0.05)
for i in range(fade):
    track[i] *= i / fade; track[-1 - i] *= i / fade
save("music.wav", track)
print("ok")
