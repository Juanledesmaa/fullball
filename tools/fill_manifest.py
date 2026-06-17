#!/usr/bin/env python3
"""Auto-author tools/player_manifest.csv: names, epithets (icons), nations
(proposed from filename art hints), regular-tier rarity, and stats.
Deterministic. Usage: python3 tools/fill_manifest.py  (rewrites the CSV in place)."""
import csv, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "tools/player_manifest.csv")

# Short, fictional anime-MC mononyms (61 unique). No real-player given names.
NAMES = ["Kaito","Ren","Sora","Riku","Haru","Yuto","Kenji","Daichi","Takumi","Akira",
 "Ryo","Sho","Kazu","Hiroshi","Jin","Rei","Tora","Kai","Yuki","Shin",
 "Raiden","Goro","Taiga","Aoi","Hayato","Itsuki","Kuro","Mako","Nori","Osamu",
 "Reo","Satoru","Tatsu","Eiji","Fuma","Genji","Ichiro","Joji","Koji","Masa",
 "Naoki","Ryuji","Seiji","Toma","Yusei","Zen","Arata","Banri","Chiro","Daigo",
 "Enzo","Fumio","Gen","Haruki","Issei","Junpei","Keita","Manabu","Noboru","Ryota","Souta"]

# Epithets for the 10 icons, keyed by id.
EPITHETS = {
 "P052":"The Maestro","P053":"Quicksilver","P054":"Street King","P055":"Neon",
 "P056":"The Showman","P057":"The Phantom","P058":"The Glitch","P059":"The Menace",
 "P060":"Ankle Breaker","P061":"The Artist"}

# Curated nation subset (all have bundled flags). Candidate lists by skin tone.
SKIN_NATIONS = {
 "verypale":["GER","NED","CRO","ENG","BEL"],
 "fair":    ["GER","ENG","NED","BEL","CRO"],
 "olive":   ["ESP","POR","ARG","URU","MEX"],
 "medbrown":["BRA","MEX","POR","FRA","URU"],
 "dark":    ["SEN","FRA","ENG","NED","MAR"],
}

def fnv(s: str) -> int:
    h = 1469598103934665603
    for b in s.encode(): h = ((h ^ b) * 1099511628211) & 0xFFFFFFFFFFFFFFFF
    return h

def skin_key(fn: str) -> str:
    n = fn.lower()
    if "very_pale" in n: return "verypale"
    if any(k in n for k in ["dark_skin","deep_brown","dark_brown"]): return "dark"
    if any(k in n for k in ["medium_brown","warm_brown","light_brown","golden_brown"]): return "medbrown"
    if any(k in n for k in ["olive","tan_skin","warm_tan","light_tan","pale_olive"]): return "olive"
    return "fair"  # pale/fair/light/white/freckled

def nation(cid: str, fn: str) -> str:
    n = fn.lower()
    if "messi" in n or "argentin" in n: return "ARG"
    if "neymar" in n or "brazil" in n: return "BRA"
    if "samurai" in n: return "JPN"
    if "monk" in n: return "KOR"
    cands = SKIN_NATIONS[skin_key(fn)]
    return cands[fnv(cid) % len(cands)]

GOLD = ["superstar","maestro","magician","monster","electric_prince","veteran_captain",
        "mysterious_genius","analytical_genius","illusion"]
SILVER = ["prodigy","genius","technician","destroyer","enforcer","sprinter","speedster",
          "powerhouse","finisher","poacher","samurai","prince","showman","rival_captain",
          "ankle-breaker","neon_trickster","dribbler","monk","sleepy"]

def tier(fn: str, is_icon: bool) -> str:
    if is_icon: return "icon"
    n = fn.lower()
    if any(k in n for k in GOLD): return "gold"
    if any(k in n for k in SILVER): return "silver"
    return "bronze"

# Stat model: tier base + position profile + deterministic jitter, clamped.
TIER_BASE = {"bronze":68,"silver":76,"gold":84,"icon":89}
POS_DELTA = {  # (pace, shooting, passing, defending)
 "FWD":(8,10,0,-14), "MID":(2,0,10,-2), "DEF":(-2,-12,0,12), "GK":(-6,-16,-4,16)}

def stats(cid: str, pos: str, rar: str):
    base = TIER_BASE[rar]; d = POS_DELTA[pos]; out=[]
    h = fnv(cid+pos)
    for i,delta in enumerate(d):
        j = ((h >> (i*8)) & 0xFF) % 7 - 3   # jitter -3..+3
        out.append(max(40, min(99, base + delta + j)))
    return out  # pace, shooting, passing, defending

def main():
    rows = list(csv.DictReader(open(CSV)))
    assert len(rows) == 61, f"expected 61 rows, got {len(rows)}"
    for i, r in enumerate(rows):
        cid = r["id"]; fn = r["sourceFile"]; pos = r["position"]
        is_icon = r["sourceDir"].rstrip("/").upper().endswith("ICONS")
        r["name"] = NAMES[i]
        r["epithet"] = EPITHETS.get(cid, "") if is_icon else ""
        r["nationTag"] = nation(cid, fn)
        r["rarity"] = tier(fn, is_icon)
        p,s,pa,de = stats(cid, pos, r["rarity"])
        r["pace"],r["shooting"],r["passing"],r["defending"] = p,s,pa,de
    cols = ["id","sourceFile","sourceDir","name","epithet","nationTag",
            "position","rarity","pace","shooting","passing","defending"]
    with open(CSV,"w",newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
    # quick distribution report
    import collections
    print("rarity:", dict(collections.Counter(r["rarity"] for r in rows)))
    print("nations:", dict(collections.Counter(r["nationTag"] for r in rows)))

if __name__ == "__main__":
    main()
