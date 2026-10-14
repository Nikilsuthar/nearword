#!/usr/bin/env python3
"""Builds NearWord's on-device semantic data from GloVe (gensim format).

Inputs (download once, see README):
    glove-wiki-gigaword-100.model  (+ .model.vectors.npy next to it)
    NLTK WordNet (nltk.download('wordnet', download_dir=...))

Usage:
    python tools/build_embeddings.py --model <path/to/glove...model> \
        --nltk-data <dir containing corpora/wordnet.zip> [--vocab 100000]

Outputs (assets/data/):
    vocab.txt        one guessable word per line (frequency ordered)
    vectors.bin      int8, N x DIM, mean-centred + L2-normalised, x127
    meta.json        {"count": N, "dim": DIM}
    secrets.txt      "word,regularTier,indiaTier" lines - possible answers
                       tiers: 0 easy, 1 medium, 2 hard, - = not in that set
    categories.json  themed answer pools, derived from the embedding itself

Tiers (how hard the answer is to GUESS, i.e. how familiar the word is):
    easy   very common concrete everyday nouns (dog, bread, train ...)
    medium common nouns incl. abstract ones (planet, memory, courage ...)
    hard   less common but still ordinary nouns (anchor, glacier, tribute ...)
"""
import argparse
import json
import pathlib
import re

import numpy as np
from gensim.models import KeyedVectors

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "data"

CATEGORIES = [
    ("animals", "Animals", "pets", False,
     ["animal", "dog", "cat", "bird", "fish", "horse", "lion", "insect"]),
    ("food", "Food", "restaurant", False,
     ["food", "bread", "fruit", "cheese", "meat", "vegetable", "dessert"]),
    ("home", "Home", "home", False,
     ["house", "kitchen", "furniture", "bedroom", "door", "window"]),
    ("school", "School", "school", False,
     ["school", "teacher", "student", "exam", "book", "classroom"]),
    ("india", "India", "temple_hindu", False,
     ["india", "cricket", "bollywood", "diwali", "chai", "rupee", "temple",
      "festival", "curry", "village"]),
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
pimp hooker stripper brothel dildo orgasm semen condom abortion crotch breast breasts nipple nipples buttocks nigger nigga fuck fucking shit bitch bastard cunt whore slut rape rapist porn
nazi hitler pussy dick cock penis vagina anus damn kike fag faggot retard
terrorist suicide genocide sex sexual sexy nude naked erotic prostitute
murder murderer kill killer killing corpse massacre torture abuse molest
drug drugs cocaine heroin marijuana opium alcohol vodka whisky beer wine
cigarette tobacco gambling casino slave slavery caste untouchable
""".split())

# Words an Indian player knows from daily life (Hinglish/English). "core" words
# are treated as EASY, "extended" as MEDIUM.
INDIA_CORE = """
chai tea roti naan dosa idli samosa biryani paneer curry masala lassi mango
banana coconut rice dal ghee sweets jalebi ladoo diwali holi eid christmas
wedding temple mosque church yoga cricket bollywood sari saree kurta turban
bindi henna mehndi rupee rickshaw bus train railway station bazaar market
village city farmer tractor monsoon river ganga himalaya tiger elephant
peacock cow buffalo camel parrot lotus mother father brother sister
grandmother grandfather uncle aunt school teacher exam college doctor
engineer police army soldier king queen palace fort festival dance music song
cinema movie hero actor film mobile phone cycle scooter bike truck auto taxi
flight airport hotel restaurant kitchen bedroom bathroom balcony terrace
garden flower rose jasmine marigold spice pepper chili onion potato tomato
garlic ginger lemon apple orange grape guava papaya watermelon cucumber carrot
milk curd butter cheese bread egg chicken fish mutton vegetable fruit snack
tiffin lunch dinner breakfast plate spoon glass bottle bucket umbrella shoes
slipper shirt pants jeans dress cap watch ring necklace bangle gold silver
diamond money bank shop shopkeeper customer price discount sale
""".split()

INDIA_EXTENDED = """
cricketer batsman bowler wicket stadium tournament captain umpire kabaddi
hockey badminton wrestling carrom chess ludo kite firecracker rangoli diya
lantern pilgrimage priest monk guru ashram meditation shrine
mountain valley desert beach island lake waterfall jungle forest sunrise
sunset summer winter rain flood drought harvest crop wheat sugarcane
cotton coffee spices saffron cardamom cinnamon clove tamarind pickle
chutney sambar kheer halwa pudding sweetshop bakery street lane
highway bridge metro subway signal traffic petrol diesel engine driver
conductor passenger ticket luggage platform parliament election minister
president flag anthem constitution court judge lawyer worker labourer
tailor carpenter plumber electrician mechanic barber potter weaver painter
singer dancer musician writer poet author editor reporter newspaper magazine
television radio camera computer laptop internet website message email
""".split()

EVERYDAY = """house kitchen food bread fruit vegetable dog cat bird fish tree
flower water river mountain hand head eye shirt shoes table chair bed door car
bus train book pen school teacher doctor milk egg rice ball toy phone clock bag
garden road village family friend mother father child baby market shop""".split()
NEWSY = """government minister president election policy economy company commission
bank court law military war tax budget party trade industry official committee
agency investment regime senate congress legislation reform ministry""".split()

# Words whose GloVe meaning is a different sense (company, surname, city ...).
DENY_INDIA = set("chai dal sari bindi ludo diya tiffin apple lotus buffalo rose "
                 "fort".split())

ALPHA = re.compile(r"^[a-z]+$")
CONCRETE = {
    "noun.animal", "noun.artifact", "noun.body", "noun.food", "noun.plant",
    "noun.object", "noun.substance", "noun.person", "noun.location",
    "noun.phenomenon", "noun.group",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--nltk-data", required=True)
    ap.add_argument("--vocab", type=int, default=100000)
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

    # --- WordNet helpers ---------------------------------------------------
    known_cache = {}

    def known(w):
        if w not in known_cache:
            known_cache[w] = any(
                l == w for s in wn.synsets(w) for l in s.lemma_names())
        return known_cache[w]

    def noun_info(w):
        """(is_base_noun, concrete_first_sense)."""
        syns = wn.synsets(w, pos="n")
        base = any(l == w for s in syns for l in s.lemma_names())
        if not base:
            return False, False
        return True, syns[0].lexname() in CONCRETE

    # --- candidate answers ---------------------------------------------------
    def noun_share(w):
        """Share of the word's usage that is as a noun (WordNet counts)."""
        tot = {"n": 0.0, "o": 0.0}
        for syn in wn.synsets(w):
            for lem in syn.lemmas():
                if lem.name().lower() == w:
                    tot["n" if syn.pos() == "n" else "o"] += lem.count() + 0.5
        t = tot["n"] + tot["o"]
        return tot["n"] / t if t else 0.0

    everyday = np.mean([mat[index[w]] for w in EVERYDAY if w in index], axis=0)
    everyday /= np.linalg.norm(everyday)
    newsy = np.mean([mat[index[w]] for w in NEWSY if w in index], axis=0)
    newsy /= np.linalg.norm(newsy)
    ev_score = mat @ everyday - mat @ newsy  # >0: everyday life, <0: news

    BAD_END = ("ing", "ly", "ness", "ment", "tion", "sion", "ity")
    cand = []  # (word, rank, concrete, share)
    for rank, w in enumerate(words):
        if rank < 40 or rank > 55000:
            continue
        if not 3 <= len(w) <= 10 or w in BLOCK:
            continue
        base, concrete = noun_info(w)
        if not base:
            continue
        if w.endswith("s") and w[:-1] in index and not w.endswith("ss"):
            continue  # plural of another vocab word
        if w.endswith(("ing", "ly", "ed")) and len(w) > 5:
            continue
        share = noun_share(w)
        if share < 0.55:
            continue  # mostly a verb/adjective (die, throw, gray, step ...)
        cand.append((w, rank, concrete, share))

    # Familiarity tiers for the REGULAR set.
    def tier_regular(w, rank, concrete):
        e = ev_score[index[w]]
        if concrete and rank < 12000 and e > -0.01:
            return 0
        if rank < 20000 and (concrete or rank < 12000) and e > -0.04:
            return 1
        if rank < 40000:
            return 2
        return None

    # Neighbourhood quality: drop answers whose nearest words are mostly
    # names / places / abbreviations (news-text artefacts).
    junk_limit = {0: 8, 1: 9, 2: 10}
    reg = {}  # word -> (tier, concrete)
    cand_idx = np.array([index[w] for w, _, _, _ in cand])
    for start in range(0, len(cand), 300):
        block = mat[cand_idx[start:start + 300]] @ mat.T
        for row, (w, rank, concrete, _) in zip(block, cand[start:start + 300]):
            tier = tier_regular(w, rank, concrete)
            if tier is None:
                continue
            top = np.argpartition(-row, 26)[:26]
            top = top[np.argsort(-row[top])]
            neigh = [words[j] for j in top if words[j] != w][:20]
            junk = sum(1 for n in neigh if not known(n))
            if junk < junk_limit[tier]:
                reg[w] = (tier, concrete)

    # --- India word set --------------------------------------------------------
    def neighbour_junk(w):
        row = mat @ mat[index[w]]
        top = np.argpartition(-row, 26)[:26]
        top = top[np.argsort(-row[top])]
        neigh = [words[j] for j in top if words[j] != w][:20]
        # Rare unknown tokens (surnames, place fragments) = junk; frequent
        # proper nouns (england, ...) are fine neighbours for e.g. 'cricket'.
        return sum(1 for n in neigh if not known(n) and index[n] > 20000)

    india_core, india_ext, dropped_in = [], [], []
    for group, out in ((INDIA_CORE, india_core), (INDIA_EXTENDED, india_ext)):
        for w in dict.fromkeys(group):
            if w not in index or w in BLOCK:
                continue
            if w in DENY_INDIA:
                dropped_in.append(w)
                continue
            out.append(w)
    print("India words dropped (poor neighbourhood):", dropped_in)

    # India tiers: familiar everyday words, never complex.
    ind = {}  # word -> tier
    for w, (tier, concrete) in reg.items():
        rank = index[w]
        if tier == 0 and rank < 6000 and ev_score[index[w]] > 0.02:
            ind[w] = 0
        elif tier == 0:
            ind[w] = 1
        elif tier == 1 and concrete and ev_score[index[w]] > 0.0:
            ind[w] = 1
        elif tier == 1 and rank < 12000:
            ind[w] = 2   # common abstract words are the India "hard"
        elif tier == 2 and concrete and rank < 20000 and ev_score[index[w]] > 0.0:
            ind[w] = 2
    for w in india_core:
        ind[w] = 0
    for w in india_ext:
        ind[w] = min(ind.get(w, 1), 1)

    secrets = {}
    for w in set(reg) | set(ind):
        secrets[w] = (reg[w][0] if w in reg else None, ind.get(w))
    # Indian-only terms must not appear in the regular set.
    sec_words = sorted(secrets, key=lambda w: index[w])
    sec_idx = np.array([index[w] for w in sec_words])

    def count(which):
        return [sum(1 for w in sec_words if secrets[w][which] == t)
                for t in range(3)]

    print("vocab", len(words), "secrets", len(sec_words))
    print(" regular easy/medium/hard =", count(0))
    print(" india   easy/medium/hard =", count(1))

    # --- categories ---------------------------------------------------------------
    cats = []
    for cid, name, icon, premium, seeds in CATEGORIES:
        v = np.mean([mat[index[s]] for s in seeds if s in index], axis=0)
        v /= np.linalg.norm(v)
        simc = mat[sec_idx] @ v
        order = np.argsort(-simc)[:900]
        pool = [sec_words[j] for j in order if sec_words[j] not in seeds[:1]]
        cats.append({"id": cid, "name": name, "icon": icon,
                     "premium": premium, "words": pool})

    # --- write ----------------------------------------------------------------------
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "vocab.txt").write_text("\n".join(words), encoding="utf-8")
    q = np.clip(np.rint(mat * 127), -127, 127).astype(np.int8)
    (OUT / "vectors.bin").write_bytes(q.tobytes())
    (OUT / "meta.json").write_text(
        json.dumps({"count": len(words), "dim": int(mat.shape[1])}))
    (OUT / "secrets.txt").write_text(
        "\n".join(
            "%s,%s,%s" % (
                w,
                "-" if secrets[w][0] is None else secrets[w][0],
                "-" if secrets[w][1] is None else secrets[w][1],
            )
            for w in sec_words),
        encoding="utf-8")
    (OUT / "categories.json").write_text(
        json.dumps(cats, separators=(",", ":")), encoding="utf-8")

    # --- sanity report -----------------------------------------------------------------
    import random
    random.seed(11)
    for which, name in ((0, "REGULAR"), (1, "INDIA")):
        for t, label in enumerate(["easy", "medium", "hard"]):
            pool = [w for w in sec_words if secrets[w][which] == t]
            print(name, label, len(pool), random.sample(pool, min(22, len(pool))))
    for probe in ("dog", "cricket", "temple", "mango"):
        if probe in index:
            sc = (q.astype(np.float32) @ q[index[probe]].astype(np.float32))
            near = [words[j] for j in np.argsort(-sc)[1:11]]
            print(probe, "->", ", ".join(near))


if __name__ == "__main__":
    main()
