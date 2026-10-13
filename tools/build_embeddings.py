#!/usr/bin/env python3
"""Builds NearWord's on-device semantic data from GloVe (gensim format).

Inputs (download once, see README):
    glove-wiki-gigaword-100.model  (+ .model.vectors.npy next to it)
    NLTK WordNet (nltk.download('wordnet', download_dir=...))

Usage:
    python tools/build_embeddings.py --model <path/to/glove...model> \
        --nltk-data <dir containing corpora/wordnet.zip> [--vocab 40000]

Outputs (assets/data/):
    vocab.txt        one guessable word per line (frequency ordered)
    vectors.bin      int8, N x DIM, mean-centred + L2-normalised, x127
    meta.json        {"count": N, "dim": DIM}
    secrets.txt      "word,difficulty" lines - words that may be the answer
    categories.json  themed answer pools, derived from the embedding itself
"""
import argparse
import json
import pathlib
import re

import numpy as np
from gensim.models import KeyedVectors

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "data"

# Themed pools are the secrets nearest to these seed words, so no hand-made
# word lists are needed.
CATEGORIES = [
    ("animals", "Animals", "pets", False,
     ["animal", "dog", "cat", "bird", "fish", "horse", "lion", "insect"]),
    ("food", "Food", "restaurant", False,
     ["food", "bread", "fruit", "cheese", "meat", "vegetable", "dessert"]),
    ("sports", "Sports", "sports_soccer", False,
     ["sport", "football", "tennis", "athlete", "tournament", "olympic"]),
    ("technology", "Technology", "devices", False,
     ["technology", "computer", "software", "internet", "robot", "digital"]),
    ("nature", "Nature", "park", False,
     ["nature", "forest", "river", "mountain", "ocean", "weather", "plant"]),
    ("transport", "Transport", "directions_car", False,
     ["vehicle", "car", "train", "airplane", "ship", "road", "traffic"]),
    ("jobs", "Jobs", "work", True,
     ["profession", "doctor", "teacher", "engineer", "worker", "career"]),
    ("music", "Music", "music_note", True,
     ["music", "song", "guitar", "orchestra", "singer", "concert"]),
    ("space", "Space", "rocket_launch", True,
     ["space", "planet", "star", "galaxy", "astronaut", "orbit"]),
    ("body", "Body & Health", "favorite", True,
     ["body", "heart", "brain", "disease", "medicine", "hospital"]),
]

BLOCK = set("""
nigger nigga fuck fucking shit bitch bastard cunt whore slut rape rapist porn
nazi hitler pussy dick cock penis vagina anus damn kike fag faggot retard
terrorist suicide genocide
""".split())

ALPHA = re.compile(r"^[a-z]+$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--nltk-data", required=True)
    ap.add_argument("--vocab", type=int, default=40000)
    args = ap.parse_args()

    import nltk
    nltk.data.path.insert(0, args.nltk_data)
    from nltk.corpus import wordnet as wn

    kv = KeyedVectors.load(args.model, mmap="r")
    keys = kv.index_to_key

    # --- guessable vocabulary -------------------------------------------
    idx = []
    for i, w in enumerate(keys):
        if len(idx) >= args.vocab:
            break
        if ALPHA.match(w) and 2 <= len(w) <= 15 and w not in BLOCK:
            idx.append(i)
    words = [keys[i] for i in idx]
    mat = np.asarray(kv.vectors[idx], dtype=np.float32)
    mat -= mat.mean(axis=0, keepdims=True)  # "all-but-the-top" style centring
    mat /= np.linalg.norm(mat, axis=1, keepdims=True) + 1e-9
    index = {w: i for i, w in enumerate(words)}

    # --- secrets: common, singular, lowercase WordNet nouns ---------------
    def is_base_noun(w):
        for s in wn.synsets(w, pos="n"):
            for l in s.lemma_names():
                if l == w:
                    return True
        return False

    secrets = []
    for rank, w in enumerate(words):
        if rank < 250 or rank > 14000:
            continue
        if not 4 <= len(w) <= 9 or w in BLOCK:
            continue
        if not is_base_noun(w):
            continue
        if w.endswith("s") and w[:-1] in index and not w.endswith("ss"):
            continue  # plural of another vocab word
        diff = "easy" if rank < 3500 else "medium" if rank < 8000 else "hard"
        secrets.append((w, diff))
    # --- quality filter ---------------------------------------------------
    # GloVe-Gigaword is trained on newswire, so some ordinary words ("globe",
    # "post") have neighbourhoods full of newspapers, places and surnames.
    # Drop answers whose nearest neighbours are mostly such non-dictionary
    # tokens (no lowercase WordNet entry), so every puzzle is fair.
    known_cache = {}

    def known(w):
        if w not in known_cache:
            known_cache[w] = any(
                l == w for s in wn.synsets(w) for l in s.lemma_names())
        return known_cache[w]

    kept = []
    dropped = []
    cand_idx = np.array([index[w] for w, _ in secrets])
    for start in range(0, len(secrets), 400):
        block = mat[cand_idx[start:start + 400]] @ mat.T
        for row, (w, d) in zip(block, secrets[start:start + 400]):
            top = np.argpartition(-row, 26)[:26]
            top = top[np.argsort(-row[top])]
            neigh = [words[j] for j in top if words[j] != w][:20]
            junk = sum(1 for n in neigh if not known(n))
            (dropped if junk >= 5 else kept).append((w, d, junk))
    print("quality filter dropped", len(dropped), "e.g.",
          [w for w, _, _ in dropped[:25]])
    secrets = [(w, d) for w, d, _ in kept]
    sec_words = [w for w, _ in secrets]
    sec_idx = np.array([index[w] for w in sec_words])
    print("vocab", len(words), "secrets", len(secrets))

    # --- categories -------------------------------------------------------
    cats = []
    for cid, name, icon, premium, seeds in CATEGORIES:
        v = np.mean([mat[index[s]] for s in seeds if s in index], axis=0)
        v /= np.linalg.norm(v)
        sims = mat[sec_idx] @ v
        order = np.argsort(-sims)[:260]
        pool = [sec_words[j] for j in order if sec_words[j] not in seeds[:1]]
        cats.append({"id": cid, "name": name, "icon": icon,
                     "premium": premium, "words": pool})

    # --- write ------------------------------------------------------------
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "vocab.txt").write_text("\n".join(words), encoding="utf-8")
    q = np.clip(np.rint(mat * 127), -127, 127).astype(np.int8)
    (OUT / "vectors.bin").write_bytes(q.tobytes())
    (OUT / "meta.json").write_text(
        json.dumps({"count": len(words), "dim": int(mat.shape[1])}))
    (OUT / "secrets.txt").write_text(
        "\n".join(f"{w},{d}" for w, d in secrets), encoding="utf-8")
    (OUT / "categories.json").write_text(
        json.dumps(cats, separators=(",", ":")), encoding="utf-8")

    # --- sanity report ----------------------------------------------------
    import random
    random.seed(7)
    for probe in ["dog", "pizza", "globe"] + random.sample(sec_words, 12):
        if probe in index:
            s = (q.astype(np.float32) @ q[index[probe]].astype(np.float32))
            near = [words[j] for j in np.argsort(-s)[1:11]]
            print(probe, "->", ", ".join(near))


if __name__ == "__main__":
    main()
