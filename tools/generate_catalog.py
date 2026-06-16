#!/usr/bin/env python3
"""Generate Fullball's fictional card catalog, banners and fixtures.

Data provenance: nation set + stat distributions were *inspired* by
api-football v3 (World Cup 2022, league=1) — used only as structural
reference for realistic positions and rating spreads. No real player
names, faces or likenesses are used (App Store / likeness constraint):
every player is a stylized placeholder like "ARG #10". The nation list
lives in tools/wc_nations.json so this regenerates with no API key.

Usage:  python3 tools/generate_catalog.py
"""
import json, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "..", "Fullball", "Resources")
random.seed(2022)

nations = json.load(open(os.path.join(HERE, "wc_nations.json")))  # [[code,name],...]
codes = [c for c, _ in nations]
positions = ["GK", "DEF", "MID", "FWD"]
pos_symbol = {"GK": "figure.handball", "DEF": "shield.lefthalf.filled",
              "MID": "figure.run", "FWD": "figure.soccer"}

# api-football ratings (~6.3-7.2) mapped to a 0-99 overall target per rarity.
rarity_overall = {"bronze": 62, "silver": 70, "gold": 78, "epic": 85, "icon": 91}


def stats_for(rar, pos):
    ov = rarity_overall[rar]
    def jit(n): return max(38, min(99, int(n + random.randint(-5, 5))))
    if pos == "FWD":   base = {"pace": ov + 5, "shooting": ov + 6, "passing": ov - 3, "defending": ov - 18}
    elif pos == "MID": base = {"pace": ov, "shooting": ov - 2, "passing": ov + 6, "defending": ov - 4}
    elif pos == "DEF": base = {"pace": ov - 2, "shooting": ov - 16, "passing": ov - 2, "defending": ov + 7}
    else:              base = {"pace": ov - 10, "shooting": ov - 24, "passing": ov - 4, "defending": ov + 9}
    return {k: jit(v) for k, v in base.items()}


cards, used = [], set()
def add(code, num, pos, rar):
    cid = f"{code}-{num}"
    if cid in used:
        return False
    used.add(cid)
    cards.append({"id": cid, "player": {"id": cid, "displayName": f"{code} #{num}",
        "nationTag": code, "shirtNumber": num, "position": pos, "stats": stats_for(rar, pos)},
        "rarity": rar, "artRef": pos_symbol[pos]})
    return True


for c, n, p in [("ARG", 10, "FWD"), ("FRA", 10, "FWD"), ("BRA", 10, "FWD"), ("POR", 7, "FWD"),
                ("ENG", 9, "FWD"), ("ESP", 9, "FWD"), ("NED", 4, "DEF"), ("CRO", 10, "MID")]:
    add(c, n, p, "icon")
for c, n, p in [("BEL", 7, "MID"), ("GER", 8, "MID"), ("URU", 9, "FWD"), ("USA", 10, "MID"),
                ("MEX", 9, "FWD"), ("SEN", 10, "FWD"), ("KOR", 7, "FWD"), ("JPN", 8, "MID")]:
    add(c, n, p, "epic")
for c, n, p in [("ARG", 11, "FWD"), ("FRA", 6, "MID"), ("BRA", 9, "FWD"), ("ENG", 8, "MID"),
                ("ESP", 6, "MID"), ("POR", 3, "DEF"), ("NED", 10, "FWD"), ("GER", 1, "GK"),
                ("CRO", 7, "MID"), ("MAR", 5, "DEF"), ("POL", 9, "FWD"), ("DEN", 10, "MID"),
                ("SUI", 23, "GK"), ("CAN", 19, "FWD")]:
    add(c, n, p, "gold")


def fill(rar, count):
    a = 0
    while a < count:
        if add(random.choice(codes), random.randint(2, 26), random.choice(positions), rar):
            a += 1
fill("silver", 22)
fill("bronze", 28)

json.dump({"nations": [{"tag": c, "name": nm} for c, nm in nations], "cards": cards},
          open(os.path.join(RES, "catalog.json"), "w"), indent=2)

json.dump([
    {"id": "standard", "title": "Global Scout", "subtitle": "Always-on standard pool",
     "type": "standard", "featuredCardIDs": [], "singleCost": {"ticket": 1}, "multiCost": {"gems": 1500}},
    {"id": "featured", "title": "Today's Match", "subtitle": "ARG #10 & FRA #10 rate-up",
     "type": "featured", "featuredCardIDs": ["ARG-10", "FRA-10"], "singleCost": {"ticket": 1}, "multiCost": {"gems": 1500}},
], open(os.path.join(RES, "banners.json"), "w"), indent=2)


def ev(i, m, pid, kind, pts, ft):
    return {"id": i, "minute": m, "playerID": pid, "kind": kind, "points": pts, "formTokens": ft}

json.dump([
    {"id": "f1", "homeTag": "ARG", "awayTag": "FRA", "group": "Final", "venue": "Lusail Stadium", "status": "live",
     "scriptedEvents": [ev("f1e1", 3, "ARG-10", "goal", 150, 3), ev("f1e2", 6, "FRA-10", "goal", 150, 3),
                        ev("f1e3", 9, "ARG-11", "assist", 60, 1), ev("f1e4", 12, "FRA-6", "yellowCard", -10, 0)]},
    {"id": "f2", "homeTag": "BRA", "awayTag": "CRO", "group": "Quarter-final", "venue": "Education City", "status": "live",
     "scriptedEvents": [ev("f2e1", 4, "BRA-10", "goal", 150, 3), ev("f2e2", 8, "CRO-10", "assist", 60, 1),
                        ev("f2e3", 11, "BRA-9", "goal", 120, 2)]},
    {"id": "f3", "homeTag": "ENG", "awayTag": "ESP", "group": "Group B", "venue": "Al Bayt Stadium", "status": "live",
     "scriptedEvents": [ev("f3e1", 5, "ENG-9", "goal", 150, 3), ev("f3e2", 10, "ESP-9", "save", 40, 1)]},
    {"id": "f4", "homeTag": "POR", "awayTag": "NED", "group": "Round of 16", "venue": "Stadium 974", "status": "upcoming",
     "scriptedEvents": [ev("f4e1", 7, "POR-7", "goal", 150, 3), ev("f4e2", 14, "NED-4", "cleanSheet", 80, 2)]},
], open(os.path.join(RES, "fixtures.json"), "w"), indent=2)

from collections import Counter
print("cards:", len(cards), dict(Counter(c["rarity"] for c in cards)))
