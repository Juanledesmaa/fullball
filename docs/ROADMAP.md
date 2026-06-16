# Status & Roadmap

Snapshot of what's built, what's intentionally fake, the rough edges, and where
to go next. Keep this honest — it's the first thing a future session should read
to avoid re-discovering known gaps.

## ✅ Done (works, offline, tested where it matters)

- **Agent framing** end to end: Scout · Market · Roster · Live · Agencies + Wallet bar (Cash/Gems/Scouts/Rep).
- **Scout (gacha)**: banners, ×1/×10, soft+hard pity, 50/50, disclosed Odds sheet, animated reveal (stagger, rarity flare, haptics), pity bar.
- **Transfer Market**: deterministic daily shortlist of specific marquee clients, Cash signings.
- **Roster (collection)**: grid, rarity/position filters, DEX completion, squad rating, taller all-corners-rounded portrait tiles, empty-state CTA.
- **Card Detail**: full vertical portrait hero; stats; Train (level-up); Limit Break (consume copies).
- **Live**: field XI + captain (×2), pay Cash entry, fixed-duration matches, **concurrent** entries, running score, FULL TIME settlement + win bonus, "your earners per match" clarity, merged event feed, matchday hero (points/career/Rep/Cash/XI-live), milestone progress + toast.
- **Procedural + persisted match slates** (device + 8h-block seeded; survive relaunch; refresh-for-Gems).
- **Economy closed**: live commission (Cash) + Rep, milestones (Gems/Scouts), Rep Exchange, daily drop.
- **Agencies**: local leaderboard, user highlighted.
- **Portraits**: 150 bundled illustrated portraits, deterministic per card, top-anchored crop, full image on detail.
- **Funny names**, **onboarding intro**, **light/dark** theme with adaptive contrast.
- **Tooling**: XcodeGen project, `tools/generate_catalog.py`, dev launch args, 41 passing tests.

## 🟡 Stubbed / fake on purpose (MVP scope)

- **No real IAP** — the Gems "buy" button shows "coming soon". The Gem sinks (10-pulls, slate refresh) create the *demand*; StoreKit is where real revenue would plug in. **This is the #1 thing to wire for monetization** (and needs the real 3.1.1 review path).
- **api-football loader is opt-in & off by default** — set `APIFootballKey` to enable; otherwise bundled JSON. Live/remote catalog still fictionalizes names.
- **All services are mock/local** — no backend, no auth, no accounts, no cloud sync, no push, no localization.
- **Leaderboard rivals are a fixed list**; not real users.
- **Match slates are session/day-local**; no shared/server fixtures.

## 🔧 Known rough edges / TODO

- **Card Detail not visually verified from automation** — navigation needs a tap; computer-use screen-recording was ungranted, so the full-portrait hero was shipped on build-correctness + logic, not a screenshot. **Eyeball it on device.**
- **Transfer prices vs starter Cash**: cheapest listing (~4,240) > starter (2,500). Intended grind, but may feel gated early — tune `TransferRules` / starter Cash if so.
- **Avatar art is anime school-students, not footballers** (the bundle the user supplied). The card frame/name/nation carries the football context. If a football-kit set arrives, it's a drop-in swap into `Resources/Avatars/` + `AvatarAssets.count`.
- **Only 150 of 399 source portraits bundled** (even spacing for variety, ~5.8 MB). Bump to 399 (~+10 MB) for less repetition on a full 80-card roster — rerun the crop with `N=399`.
- **Portrait crop is a fixed top square** (2% offset); a few source poses have a hand near the face. Per-image blacklist/tuning possible if any bug you.
- **Market has no gem-refresh** (unlike the match slate) — could add the same `RefreshRules`-style sink.
- **`fixtures.json` is now unused** by Live (generator replaced it) — still loaded by `CatalogService`; harmless, could be removed.
- **api-football key**: a real key was shared in chat during development — **rotate it** before any production use; it is NOT stored in the repo.

## 🚀 Suggested next steps (roughly prioritized)

1. **StoreKit seam for Gems** — turn the stub into a real (or sandbox) IAP; `AvatarView`-style single seam behind the buy button. Unlocks monetization.
2. **"Today" home hub** — a landing tab tying live matches × your holdings × daily × next action into one glance (the biggest remaining clarity lever; the WC26 wireframe originally had a Today screen).
3. **Objectives / quests** — a rewarded checklist turning systems into next-taps ("sign a client", "field an XI", "win a match", "reach squad 80").
4. **Settings** — sound/haptics toggles, restore purchases, a place for legal/odds.
5. **More portraits** (399) + optional football-kit art set.
6. **Persistence polish** — persist matchday session points; consider migrating SwiftData carefully (additive fields only) as models grow.
7. **Real backend behind the protocols** — `CatalogLoading` already proves the seam; add remote wallet/leaderboard the same way.

## Design constraints to never violate (recap)

iPhone-only portrait · SwiftUI + `@Observable` MVVM · Swift 6 strict concurrency · iOS 17 · **no real player likeness / kits / crests** · virtual currency only · disclose gacha odds · zero third-party deps · no "Co-Authored-By" trailer in commits. Full list in [CLAUDE.md](../CLAUDE.md).
