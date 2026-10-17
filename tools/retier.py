"""Post-process secrets_base.txt -> assets/data/secrets.txt.

Makes Easy genuinely easy (common, concrete, everyday nouns) and moves vague
abstract words (quality, ability, ...) and odd words to the harder levels.
Format per line: word,regularTier,indiaTier  (0 easy, 1 medium, 2 hard, - none)
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
vocab = [l.strip() for l in (ROOT / "assets/data/vocab.txt").read_text(encoding="utf-8").split("\n")]
rank = {w: i for i, w in enumerate(vocab)}

ABSTRACT = ("ity", "ness", "tion", "sion", "ment", "ance", "ence", "ism", "ship",
            "hood", "ology", "ure", "age", "ics", "dom", "acy", "ery")
ABSTRACT_OK = {"village", "message", "garbage", "cottage", "bridge", "image", "page",
               "stage", "cage", "sausage", "luggage", "passage", "voyage", "orange",
               "garage", "baggage", "language", "mountain", "fountain", "station",
               "kitchen", "chicken", "question", "vegetable"}
ODD = set("""swine pastor idol lord limestone cargo freight pianist retailer servant
sheriff fossil cluster spirit globe collar outfit rifle resident pill pub cab piece
favourite warehouse manager wire fabric elevator lad lass ass wench harlot slave
prostitute porn sex sexy nude naked drug cocaine heroin cult militant terrorist
bomber murder rape corpse genocide slaughter suicide tomb ghost demon devil""".split())


def abstract(w):
    return w not in ABSTRACT_OK and w.endswith(ABSTRACT)


rows = []
for line in (ROOT / "tools/secrets_base.txt").read_text(encoding="utf-8").split("\n"):
    if not line.strip():
        continue
    w, r, i = line.split(",")
    r = None if r == "-" else int(r)
    i = None if i == "-" else int(i)
    rk = rank[w]
    bad = abstract(w)
    if w in ODD:
        r = None if r is None else 2
        i = None if i is None else 2
    if r is not None:
        if r == 0 and (rk >= 9000 or bad):
            r = 1 if not bad else 2
        elif r == 1 and (bad or rk >= 14000):
            r = 2
    if i is not None:
        if i == 0 and bad:
            i = 1
        elif i == 1 and bad:
            i = 2
    rows.append((w, r, i))

fmt = lambda v: "-" if v is None else str(v)
(ROOT / "assets/data/secrets.txt").write_text(
    "\n".join("%s,%s,%s" % (w, fmt(r), fmt(i)) for w, r, i in rows), encoding="utf-8")
for name, col in (("regular", 1), ("india", 2)):
    print(name, [sum(1 for x in rows if x[col] == t) for t in range(3)])
