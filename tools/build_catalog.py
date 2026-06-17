#!/usr/bin/env python3
"""Build Fullball/Resources/catalog.json from tools/player_manifest.csv.
Nations derived from the nationTag column (curated subset). Shirt numbers
auto-assigned per nation. Usage: python3 tools/build_catalog.py"""
import csv, json, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "tools/player_manifest.csv")
OUT = os.path.join(ROOT, "Fullball/Resources/catalog.json")
NATION_NAMES = {
 "ARG":"Argentina","BRA":"Brazil","FRA":"France","ESP":"Spain","ENG":"England",
 "GER":"Germany","JPN":"Japan","KOR":"South Korea","NED":"Netherlands","POR":"Portugal",
 "BEL":"Belgium","CRO":"Croatia","MEX":"Mexico","URU":"Uruguay","SEN":"Senegal","MAR":"Morocco",
}
VALID_POS = {"GK","DEF","MID","FWD"}
VALID_RAR = {"bronze","silver","gold","icon"}

def main():
    rows = list(csv.DictReader(open(CSV)))
    cards, tags, num = [], collections.OrderedDict(), collections.Counter()
    errors = []
    for r in rows:
        tag = r["nationTag"].strip().upper()
        pos = r["position"].strip().upper()
        rar = r["rarity"].strip().lower()
        if tag not in NATION_NAMES: errors.append(f"{r['id']}: unknown nation '{tag}'")
        if pos not in VALID_POS: errors.append(f"{r['id']}: bad position '{pos}'")
        if rar not in VALID_RAR: errors.append(f"{r['id']}: bad rarity '{rar}'")
        for k in ("pace","shooting","passing","defending"):
            if not str(r[k]).strip().isdigit(): errors.append(f"{r['id']}: bad {k} '{r[k]}'")
        if errors: continue
        num[tag] += 1
        tags[tag] = NATION_NAMES[tag]
        n = num[tag]
        pid = r["id"]
        player = {
            "id": pid, "displayName": f"{tag} #{n}", "nationTag": tag,
            "shirtNumber": n, "position": pos,
            "name": r["name"].strip(),
            "stats": {k: int(r[k]) for k in ("pace","shooting","passing","defending")},
        }
        if r["epithet"].strip():
            player["epithet"] = r["epithet"].strip()
        cards.append({"id": pid, "player": player, "rarity": rar})
    if errors:
        raise SystemExit("CSV errors:\n  " + "\n  ".join(errors))
    nations = [{"tag": t, "name": nm} for t, nm in tags.items()]
    json.dump({"nations": nations, "cards": cards}, open(OUT, "w"), indent=2)
    print(f"✓ wrote {len(cards)} cards, {len(nations)} nations -> {OUT}")

if __name__ == "__main__":
    main()
