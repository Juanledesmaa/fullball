#!/usr/bin/env python3
"""Parse source player filenames into a curation CSV scaffold.
Usage: python3 tools/parse_positions.py ~/Downloads/Regular_player ~/Downloads/ICONS > tools/player_manifest.csv
Regular dir -> tiers bronze/silver/gold (left blank for curation).
ICONS dir   -> rarity 'icon'.
Position parsed from filename; everything else left for the human to author."""
import sys, os, re, csv

def bucket(fn: str) -> str:
    n = fn.lower()
    if "goalkeeper" in n: return "GK"
    if any(k in n for k in ["center_back","centre_back","left_back","right_back",
                            "fullback","wingback","defender","enforcer"]): return "DEF"
    if any(k in n for k in ["midfield","playmaker","box-to-box","technician","destroyer"]): return "MID"
    if any(k in n for k in ["striker","winger","forward","false_nine","poacher",
                            "finisher","speedster","dribbler","trickster","speed_demon",
                            "ankle-breaker","superstar","menace","freestyle","neymar","messi"]): return "FWD"
    return "??"

def main():
    dirs = sys.argv[1:]
    w = csv.writer(sys.stdout)
    w.writerow(["id","sourceFile","sourceDir","name","epithet","nationTag",
                "position","rarity","pace","shooting","passing","defending"])
    seq = 0
    for d in dirs:
        is_icon = os.path.basename(d.rstrip("/")).upper().startswith("ICON")
        for fn in sorted(os.listdir(d)):
            if not fn.lower().endswith(".png"): continue
            seq += 1
            pos = bucket(fn)
            rarity = "icon" if is_icon else ""   # blank => author bronze/silver/gold
            cid = f"P{seq:03d}"                   # stable curation id; rename later if desired
            w.writerow([cid, fn, d, "", "", "", pos, rarity, "", "", "", ""])
    print(f"# parsed {seq} files", file=sys.stderr)

if __name__ == "__main__":
    main()
