# Asset & Catalog Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 80 generic procedural cards with 61 curated anime-style players (51 regular + 10 icons), authored short names, a 4-tier rarity system, and a live-ops catalog (Firestore metadata + Firebase Storage images with on-device cache).

**Architecture:** Two layers behind protocols (Firebase quarantined per CLAUDE.md #9). Catalog metadata: Firestore `catalog/current` doc + bundled `catalog.json` fallback, resolved through the existing `CatalogLoading` async seam. Images: Firebase Storage `players/{id}.jpg` via a new `PlayerImageStore` (memory→disk→Storage), replacing the hash-mapped `AvatarAssets`.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData, Firebase (Auth+Firestore already; **Storage added**), XcodeGen, Swift Testing. Python 3 + `sips` (macOS) for the asset pipeline.

**Design spec:** `docs/superpowers/specs/2026-06-17-asset-catalog-revamp-design.md`

---

## Conventions for every task

- **Test command** (pin a udid to avoid ambiguity; list with `xcrun simctl list devices available | grep "iPhone 16 "`):
  ```bash
  xcodebuild test -project Fullball.xcodeproj -scheme Fullball \
    -only-testing:FullballTests \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
- **Build command:** same with `build` instead of `test`.
- After ANY file add/remove: `xcodegen generate` before building.
- Swift Testing only (`import Testing`, `@Test`, `#expect`); pure-logic tests only (constraint #8).
- Commit after each task. No "Co-Authored-By" trailer.

---

## File Structure

**New files**
- `tools/parse_positions.py` — parse the 61 source filenames → position bucket + a CSV scaffold.
- `tools/player_manifest.csv` — curation source of truth (one row per image).
- `tools/process_players.sh` — resize/compress source PNGs → `<cardId>.jpg`, emit upload dir.
- `tools/build_catalog.py` — `player_manifest.csv` → `Fullball/Resources/catalog.json`.
- `Fullball/Services/PlayerImageStore.swift` — memory/disk/Storage image cache (protocol + Firebase impl + Mock).
- `Fullball/Services/Firestore/CatalogDTO.swift` — Firestore catalog payload DTO + domain mapping.
- `Fullball/Services/Firestore/FirestoreCatalogLoader.swift` — remote catalog loader w/ bundled fallback.
- `FullballTests/CatalogBuildTests.swift` — CSV→catalog invariants.
- `FullballTests/PlayerImageStoreTests.swift` — disk cache key (pure logic).

**Modified files**
- `Fullball/Domain/Models/Rarity.swift` — drop `epic`, re-tune odds/caps/colors.
- `Fullball/Domain/Models/Player.swift` — add `name: String?`, `epithet: String?`.
- `Fullball/Domain/Models/Card.swift` — `artRef` → optional (`String?`, default nil).
- `Fullball/Domain/Economy/GachaEngine.swift` — remove `.epic` from rolls.
- `Fullball/Domain/Economy/NameGenerator.swift` — authored-name resolver + fallback.
- `Fullball/Domain/Economy/Economy.swift` — remove epic transfer price.
- `Fullball/Services/TransferMarketService.swift` — remove `.epic` from market plan.
- `Fullball/Services/Networking/Fictionalizer.swift` — remove epic mapping.
- `Fullball/Features/PackOpening/PackRevealView.swift` — `>= .epic` → `>= .gold`.
- `Fullball/Features/Components/AssetAvatar.swift` — `AvatarView`/`CardPortraitFull` async via `PlayerImageStore`.
- `Fullball/Services/Firestore/FirestoreClient.swift` — `fetchCatalog()`.
- `Fullball/App/AppContainer.swift` — inject `PlayerImageStore`, wire `FirestoreCatalogLoader`.
- `Fullball/Mocks/PreviewSupport.swift`, `FullballTests/TestFixtures.swift`, `FullballTests/GachaEngineTests.swift`, `FullballTests/FictionalizerTests.swift` — drop `.epic`.
- `firestore.rules` + `storage.rules` — world-readable catalog/images.
- `project.yml` — add Firebase Storage product.

---

## Phase 1 — Asset pipeline & curation scaffold

Produces: a CSV scaffold with positions parsed, and compressed renamed images ready to upload. No app code yet.

### Task 1.1: Position parser → CSV scaffold

**Files:**
- Create: `tools/parse_positions.py`

- [ ] **Step 1: Write the parser**

```python
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
```

- [ ] **Step 2: Generate the scaffold**

Run:
```bash
cd /Users/juanito/Proyectos/iOS/Fullball
python3 tools/parse_positions.py ~/Downloads/Regular_player ~/Downloads/ICONS > tools/player_manifest.csv
wc -l tools/player_manifest.csv   # expect 62 (header + 61)
```
Expected: 62 lines; stderr `# parsed 61 files`.

- [ ] **Step 3: Commit**

```bash
git add tools/parse_positions.py tools/player_manifest.csv
git commit -m "tools: parse source player filenames into curation CSV scaffold"
```

> **USER ACTION (blocks Phase 4 curation):** fill `name`, `epithet` (icons only), `nationTag`, `rarity` (regulars), and the four stats in `tools/player_manifest.csv`. Fix any `position == "??"`. See action items in the spec (GK/DEF skew; pick 12–16 nations).

### Task 1.2: Image processing script

**Files:**
- Create: `tools/process_players.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Resize+compress source PNGs to <cardId>.jpg using the manifest mapping.
# Output -> build/player_images/ (gitignored). Re-runnable.
# Usage: tools/process_players.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSV="$ROOT/tools/player_manifest.csv"
OUT="$ROOT/build/player_images"
MAXH=1024            # target height in px
mkdir -p "$OUT"
tail -n +2 "$CSV" | while IFS=, read -r id src dir name epithet nation pos rarity p s pa d; do
  [ -z "${src:-}" ] && continue
  in="${dir%/}/$src"
  out="$OUT/${id}.jpg"
  if [ ! -f "$in" ]; then echo "MISSING: $in" >&2; continue; fi
  cp "$in" "$out.tmp.png"
  sips -Z "$MAXH" "$out.tmp.png" --out "$out" --setProperty format jpeg --setProperty formatOptions 80 >/dev/null
  rm -f "$out.tmp.png"
  echo "✓ $id ($src)"
done
echo "→ $(ls "$OUT" | wc -l | tr -d ' ') images in $OUT, total $(du -sh "$OUT" | cut -f1)"
```

- [ ] **Step 2: Add build/ to gitignore (if absent)**

Run:
```bash
grep -qxF "build/" .gitignore || echo "build/" >> .gitignore
```

- [ ] **Step 3: Run it (after USER fills CSV ids/sources)**

Run: `tools/process_players.sh`
Expected: `→ 61 images in .../build/player_images, total ~15M`.

- [ ] **Step 4: Commit**

```bash
git add tools/process_players.sh .gitignore
git commit -m "tools: image pipeline (resize+compress source PNGs to <id>.jpg)"
```

---

## Phase 2 — Rarity 4-tier refactor (pure logic, fully TDD)

Produces: 4-tier rarity everywhere; gacha odds re-normalized; all tests green. Self-contained — depends on no asset data.

### Task 2.1: Rewrite `Rarity` (drop epic)

**Files:**
- Modify: `Fullball/Domain/Models/Rarity.swift`

- [ ] **Step 1: Replace the enum body**

Replace the whole `enum Rarity` with:

```swift
enum Rarity: String, Codable, CaseIterable, Sendable, Comparable {
    case bronze, silver, gold, icon

    /// Disclosed base odds (sum = 1.0); must match the Odds sheet.
    var baseOdds: Double {
        switch self {
        case .bronze: return 0.70
        case .silver: return 0.22
        case .gold:   return 0.073
        case .icon:   return 0.007
        }
    }

    var rank: Int { Rarity.allCases.firstIndex(of: self)! }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        case .icon:   return "Icon"
        }
    }

    /// Max star level (limit-break cap).
    var starCap: Int {
        switch self {
        case .bronze: return 3
        case .silver: return 4
        case .gold:   return 5
        case .icon:   return 5
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(hex: 0xA8743A)
        case .silver: return Color(hex: 0x9AA0A6)
        case .gold:   return WC.gold
        case .icon:   return WC.coral
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rank < rhs.rank }
}
```

- [ ] **Step 2: Build — expect failures** at every `.epic` site (lists which files).

Run: build command. Expected: FAIL, `type 'Rarity' has no member 'epic'` in GachaEngine, Economy, TransferMarketService, Fictionalizer, PreviewSupport, PackRevealView, plus tests.

### Task 2.2: Fix `GachaEngine` rolls

**Files:**
- Modify: `Fullball/Domain/Economy/GachaEngine.swift:24-30`

- [ ] **Step 1: Replace the non-icon distribution**

```swift
        let nonIconBase = Rarity.bronze.baseOdds + Rarity.silver.baseOdds
            + Rarity.gold.baseOdds   // 0.993
        let scale = (1.0 - ico) / nonIconBase

        var cumulative = 0.0
        for rarity in [Rarity.bronze, .silver, .gold] {
            cumulative += rarity.baseOdds * scale
            if roll < cumulative { return rarity }
        }
        return .icon
```

### Task 2.3: Fix remaining non-test `.epic` sites

**Files:**
- Modify: `Economy.swift:74`, `TransferMarketService.swift:51`, `Fictionalizer.swift:21,32`, `PackRevealView.swift:13`, `PreviewSupport.swift:28`

- [ ] **Step 1: Economy.swift** — delete the `case .epic: base = 2800` line.
- [ ] **Step 2: TransferMarketService.swift:51** — change plan to `[(.icon, 2), (.gold, 3), (.silver, 1)]`.
- [ ] **Step 3: Fictionalizer.swift** — remove `case 7.2..<7.6: return .epic` (widen gold to `6.8..<7.6`) and delete `case .epic: return 85` (gold already returns its value).
- [ ] **Step 4: PackRevealView.swift:13** — `bestRarity >= .epic` → `bestRarity >= .gold`. Update the line-19 comment to "for gold+".
- [ ] **Step 5: PreviewSupport.swift:28** — change that card's `.epic` to `.gold`.

### Task 2.4: Update tests for 4 tiers

**Files:**
- Modify: `FullballTests/GachaEngineTests.swift:23`, `FullballTests/FictionalizerTests.swift:39`, `FullballTests/TestFixtures.swift:18`

- [ ] **Step 1: TestFixtures.swift:18** — change loop to `for r in [Rarity.bronze, .silver, .gold]`.
- [ ] **Step 2: GachaEngineTests.swift** — replace the epic odds expectation. The base-odds test should now assert:

```swift
#expect(abs(frac(.bronze) - 0.70) < 0.01)
#expect(abs(frac(.silver) - 0.22) < 0.01)
#expect(abs(frac(.gold)  - 0.073) < 0.01)
#expect(abs(frac(.icon)  - 0.007) < 0.004)
```
Remove the `.epic` line. (Read the surrounding test to match the existing `frac` helper + tolerance style.)

- [ ] **Step 3: FictionalizerTests.swift:39** — change `7.3` expectation to `== .gold`.

- [ ] **Step 4: Add a sum-to-one test** in `GachaEngineTests.swift`:

```swift
@Test func baseOddsSumToOne() {
    let sum = Rarity.allCases.reduce(0.0) { $0 + $1.baseOdds }
    #expect(abs(sum - 1.0) < 1e-9)
}
```

- [ ] **Step 5: Run tests**

Run: test command. Expected: PASS (all suites, no epic refs).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: collapse rarity to 4 tiers (bronze/silver/gold/icon), re-normalize gacha odds"
```

---

## Phase 3 — Authored names

Produces: cards display authored short names; generator becomes fallback. Pure logic.

### Task 3.1: Add name fields to `Player`

**Files:**
- Modify: `Fullball/Domain/Models/Player.swift`

- [ ] **Step 1: Add optional fields** to the `Player` struct (after `position`):

```swift
    let position: Position
    var name: String? = nil       // authored display name (e.g. "Kaito")
    var epithet: String? = nil    // icons only (e.g. "The Comet")
    let stats: Stats
```
(Optional with defaults keeps existing `catalog.json` and the `Card`/`Player` initializers decoding cleanly.)

### Task 3.2: Authored-name resolver + test

**Files:**
- Modify: `Fullball/Domain/Economy/NameGenerator.swift`
- Test: `FullballTests/NameGeneratorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
@Test func authoredNameWinsAndEpithetAppends() {
    let icon = Player(id: "P1", displayName: "ARG #10", nationTag: "ARG",
                      shirtNumber: 10, position: .fwd, name: "Raiden",
                      epithet: "The Comet", stats: Stats(pace:90,shooting:90,passing:80,defending:60))
    #expect(icon.funnyName == "Raiden — The Comet")
    let reg = Player(id: "P2", displayName: "BRA #7", nationTag: "BRA",
                     shirtNumber: 7, position: .fwd, name: "Kaito",
                     stats: Stats(pace:80,shooting:80,passing:80,defending:60))
    #expect(reg.funnyName == "Kaito")
}
```

- [ ] **Step 2: Run — expect fail** (`funnyName` still returns generated name).

- [ ] **Step 3: Update the `funnyName` extension** in `NameGenerator.swift`:

```swift
extension Player {
    /// Authored name if present (icons append " — epithet"); else the
    /// deterministic generated fallback.
    var funnyName: String {
        if let n = name, !n.isEmpty {
            if let e = epithet, !e.isEmpty { return "\(n) — \(e)" }
            return n
        }
        return NameGenerator.funnyName(for: id)
    }
}
```

- [ ] **Step 4: Run tests** — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: authored short names (mononym + icon epithet); generator is now fallback"
```

---

## Phase 4 — Catalog generation (offline-complete milestone)

Produces: bundled `catalog.json` regenerated from the curated CSV with 61 cards, 4 tiers, authored names, `imageRef`. App fully works offline with new identity (placeholders until images land in Phase 5). **Depends on USER having filled the CSV.**

### Task 4.1: Make `artRef` optional, add `imageRef`

**Files:**
- Modify: `Fullball/Domain/Models/Card.swift`

- [ ] **Step 1: Update `Card`**

```swift
struct Card: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let player: Player
    let rarity: Rarity
    var artRef: String? = nil   // legacy SF-symbol stand-in (unused once images land)

    var displayName: String { player.displayName }
    /// Storage path / cache key for the portrait. Convention: the card id.
    var imageRef: String { id }
}
```
(`artRef` optional → existing JSON and the API-football/Fictionalizer/CardDetailViewModel/TestFixtures call sites still compile; they pass a value, which is fine.)

- [ ] **Step 2: Build** — Expected: PASS.

### Task 4.2: CSV → catalog.json generator

**Files:**
- Create: `tools/build_catalog.py`
- Test: `FullballTests/CatalogBuildTests.swift`

- [ ] **Step 1: Write the generator**

```python
#!/usr/bin/env python3
"""Build Fullball/Resources/catalog.json from tools/player_manifest.csv.
Nations are derived from the nationTag column (curated subset). Shirt numbers
auto-assigned per nation. Usage: python3 tools/build_catalog.py"""
import csv, json, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "tools/player_manifest.csv")
OUT = os.path.join(ROOT, "Fullball/Resources/catalog.json")
NATION_NAMES = {  # extend to cover whatever tags the curation uses
 "ARG":"Argentina","BRA":"Brazil","FRA":"France","ESP":"Spain","ENG":"England",
 "GER":"Germany","JPN":"Japan","KOR":"South Korea","NED":"Netherlands","POR":"Portugal",
 "ITA":"Italy","BEL":"Belgium","CRO":"Croatia","MEX":"Mexico","URU":"Uruguay","USA":"USA",
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
            if not r[k].strip().isdigit(): errors.append(f"{r['id']}: bad {k} '{r[k]}'")
        if errors: continue
        num[tag] += 1
        tags[tag] = NATION_NAMES[tag]
        n = num[tag]
        pid = r["id"]
        cards.append({
            "id": pid,
            "player": {
                "id": pid, "displayName": f"{tag} #{n}", "nationTag": tag,
                "shirtNumber": n, "position": pos,
                "name": r["name"].strip(),
                **({"epithet": r["epithet"].strip()} if r["epithet"].strip() else {}),
                "stats": {k: int(r[k]) for k in ("pace","shooting","passing","defending")},
            },
            "rarity": rar,
        })
    if errors:
        raise SystemExit("CSV errors:\n  " + "\n  ".join(errors))
    nations = [{"tag": t, "name": nm} for t, nm in tags.items()]
    json.dump({"nations": nations, "cards": cards}, open(OUT, "w"), indent=2)
    print(f"✓ wrote {len(cards)} cards, {len(nations)} nations -> {OUT}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Generate**

Run: `python3 tools/build_catalog.py`
Expected: `✓ wrote 61 cards, N nations` (N = your curated nation count). Errors abort with a list — fix the CSV.

- [ ] **Step 3: Regenerate Xcode project & build**

Run: `xcodegen generate && <build command>`
Expected: BUILD SUCCEEDED. App now lists 61 cards with authored names.

- [ ] **Step 4: Add a catalog invariants test**

```swift
import Testing
@testable import Fullball

struct CatalogBuildTests {
    let cat = BundledCatalogService()

    @Test func has61CardsAllFourTiers() {
        #expect(cat.cards.count == 61)
        let tiers = Set(cat.cards.map(\.rarity))
        #expect(tiers == Set([.bronze, .silver, .gold, .icon]))
    }
    @Test func everyCardHasAuthoredName() {
        for c in cat.cards { #expect(!(c.player.name ?? "").isEmpty) }
    }
    @Test func iconsAreTenAndAllForwards() {
        let icons = cat.cards.filter { $0.rarity == .icon }
        #expect(icons.count == 10)
    }
    @Test func nationsCoverAllCardTags() {
        let tags = Set(cat.nations.map(\.tag))
        for c in cat.cards { #expect(tags.contains(c.player.nationTag)) }
    }
}
```

- [ ] **Step 5: Run tests** — Expected: PASS. (If `iconsAreTenAndAllForwards` count differs, reconcile with the CSV.)

- [ ] **Step 6: Commit**

```bash
git add tools/build_catalog.py Fullball/Resources/catalog.json FullballTests/CatalogBuildTests.swift
git commit -m "feat: regenerate bundled catalog from curated CSV (61 cards, 4 tiers, authored names)"
```

---

## Phase 5 — Image delivery (Storage + on-device cache)

Produces: portraits load from Firebase Storage, cached to disk+memory, with the existing placeholder while loading/offline.

### Task 5.1: Add Firebase Storage dependency

**Files:**
- Modify: `project.yml` (dependencies block, after FirebaseFirestore)
- Modify: `ci_scripts/Package.resolved` (keep in sync — see CLAUDE.md CI note)

- [ ] **Step 1: Add the product**

```yaml
      - package: Firebase
        product: FirebaseStorage
```

- [ ] **Step 2: Regenerate + resolve + build**

Run:
```bash
xcodegen generate
xcodebuild -resolvePackageDependencies -project Fullball.xcodeproj -scheme Fullball
cp Fullball.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved ci_scripts/Package.resolved
<build command>
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add project.yml ci_scripts/Package.resolved
git commit -m "build: add FirebaseStorage product for player images"
```

### Task 5.2: `PlayerImageStore` (protocol + disk-cache key test)

**Files:**
- Create: `Fullball/Services/PlayerImageStore.swift`
- Test: `FullballTests/PlayerImageStoreTests.swift`

- [ ] **Step 1: Write the failing test** (pure-logic part — the cache filename)

```swift
import Testing
@testable import Fullball

struct PlayerImageStoreTests {
    @Test func diskFilenameIsIdDotJpg() {
        #expect(DiskImageCache.filename(for: "P007") == "P007.jpg")
    }
}
```

- [ ] **Step 2: Run — expect fail** (`DiskImageCache` undefined).

- [ ] **Step 3: Write the service**

```swift
import UIKit
import FirebaseStorage

/// Async portrait source: memory → disk → Firebase Storage. Replaces the old
/// hash-mapped bundled `AvatarAssets`. Quarantines Storage from the UI.
protocol PlayerImageStore: Sendable {
    func image(for id: String) async -> UIImage?
}

/// Disk cache under Caches/players. Pure path logic is testable.
enum DiskImageCache {
    static func filename(for id: String) -> String { "\(id).jpg" }

    static var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("players", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func url(for id: String) -> URL { dir.appendingPathComponent(filename(for: id)) }

    static func load(_ id: String) -> UIImage? {
        guard let data = try? Data(contentsOf: url(for: id)) else { return nil }
        return UIImage(data: data)
    }
    static func save(_ data: Data, _ id: String) {
        try? data.write(to: url(for: id), options: .atomic)
    }
}

@MainActor
final class FirebaseImageStore: PlayerImageStore {
    private let mem = NSCache<NSString, UIImage>()
    private let storage = Storage.storage()
    private let maxBytes: Int64 = 4 * 1024 * 1024

    func image(for id: String) async -> UIImage? {
        let key = id as NSString
        if let m = mem.object(forKey: key) { return m }
        if let d = DiskImageCache.load(id) { mem.setObject(d, forKey: key); return d }
        do {
            let data = try await storage.reference(withPath: "players/\(id).jpg")
                .data(maxSize: maxBytes)
            DiskImageCache.save(data, id)
            guard let img = UIImage(data: data) else { return nil }
            mem.setObject(img, forKey: key)
            return img
        } catch {
            return nil   // caller shows placeholder
        }
    }
}

/// Preview/offline impl: never resolves an image (UI shows placeholder).
struct MockImageStore: PlayerImageStore {
    func image(for id: String) async -> UIImage? { nil }
}
```

- [ ] **Step 4: Run tests** — Expected: PASS.

### Task 5.3: Make `AvatarView`/`CardPortraitFull` async

**Files:**
- Modify: `Fullball/Features/Components/AssetAvatar.swift`

- [ ] **Step 1: Replace `AvatarView` and `CardPortraitFull`** (keep `AvatarAssets` enum for now; it becomes dead and is removed in cleanup). Read `PlayerImageStore` from the environment.

```swift
struct AvatarView: View {
    let card: Card
    @Environment(\.playerImageStore) private var store
    @State private var img: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let img {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .clipped()
        }
        .task(id: card.id) { img = await store.image(for: card.imageRef) }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(card.rarity.color.opacity(0.3))
            Image(systemName: card.player.position.symbol).foregroundStyle(.white.opacity(0.6))
        }
    }
}

struct CardPortraitFull: View {
    let card: Card
    @Environment(\.playerImageStore) private var store
    @State private var img: UIImage?

    var body: some View {
        Group {
            if let img {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                ZStack {
                    Rectangle().fill(card.rarity.color.opacity(0.3))
                    Image(systemName: card.player.position.symbol)
                        .font(.largeTitle).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .task(id: card.id) { img = await store.image(for: card.imageRef) }
    }
}
```

- [ ] **Step 2: Add the environment key** (same file, bottom)

```swift
private struct PlayerImageStoreKey: EnvironmentKey {
    static let defaultValue: any PlayerImageStore = MockImageStore()
}
extension EnvironmentValues {
    var playerImageStore: any PlayerImageStore {
        get { self[PlayerImageStoreKey.self] }
        set { self[PlayerImageStoreKey.self] = newValue }
    }
}
```

### Task 5.4: Wire the store into the container/root

**Files:**
- Modify: `Fullball/App/AppContainer.swift` (add `let imageStore: any PlayerImageStore`, default `MockImageStore()` in preview, `FirebaseImageStore()` in the real bootstrap)
- Modify: the root view that injects `.environment(container)` — add `.environment(\.playerImageStore, container.imageStore)`.

- [ ] **Step 1:** Add `imageStore` to `AppContainer` (init param defaulting to `MockImageStore()`; in `bootstrap`, pass `FirebaseImageStore()`). Read the existing init/bootstrap to match style.
- [ ] **Step 2:** In `RootView`/`FullballApp` where `.environment(container)` is set, add `.environment(\.playerImageStore, container.imageStore)`.
- [ ] **Step 3: Build** — Expected: PASS.
- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: PlayerImageStore (memory/disk/Storage) + async AvatarView; placeholder while loading"
```

> **USER ACTION:** enable Firebase **Storage** in the console; upload `build/player_images/*` to `players/` (Task 7.2).

---

## Phase 6 — Firestore catalog (live-ops)

Produces: catalog metadata read from Firestore with bundled fallback. Live-ops without releases.

### Task 6.1: Catalog DTO + mapping + test

**Files:**
- Create: `Fullball/Services/Firestore/CatalogDTO.swift`
- Test: `FullballTests/CloudDTOTests.swift` (extend existing)

- [ ] **Step 1: Write the DTO**

```swift
import Foundation

/// Firestore catalog payload at `catalog/current`. Mirrors the bundled
/// catalog.json shape so the same decoder logic applies.
struct CatalogDTO: Codable, Sendable {
    struct NationDTO: Codable, Sendable { let tag: String; let name: String }
    let nations: [NationDTO]
    let cards: [Card]   // Card/Player are already Codable

    func toData(banners: [Banner], fixtures: [Fixture]) -> CatalogData {
        CatalogData(cards: cards,
                    banners: banners,
                    fixtures: fixtures,
                    nations: nations.map { Nation(tag: $0.tag, name: $0.name) })
    }
}
```

- [ ] **Step 2: Add a mapping test** in `CloudDTOTests.swift`

```swift
@Test func catalogDTOMapsToData() throws {
    let json = """
    {"nations":[{"tag":"ARG","name":"Argentina"}],
     "cards":[{"id":"P1","player":{"id":"P1","displayName":"ARG #1","nationTag":"ARG",
       "shirtNumber":1,"position":"FWD","name":"Kaito",
       "stats":{"pace":80,"shooting":80,"passing":70,"defending":50}},"rarity":"gold"}]}
    """.data(using: .utf8)!
    let dto = try JSONDecoder().decode(CatalogDTO.self, from: json)
    let data = dto.toData(banners: [], fixtures: [])
    #expect(data.cards.count == 1)
    #expect(data.cards[0].player.funnyName == "Kaito")
    #expect(data.nations.first?.tag == "ARG")
}
```

- [ ] **Step 3: Run tests** — Expected: PASS. (If `Nation` init differs, match its real signature.)

### Task 6.2: `FirestoreClient.fetchCatalog`

**Files:**
- Modify: `Fullball/Services/Firestore/FirestoreClient.swift`

- [ ] **Step 1: Add** (near the other fetchers)

```swift
    // MARK: Catalog
    private func catalogDoc() -> DocumentReference {
        db.collection("catalog").document("current")
    }
    func fetchCatalog() async throws -> CatalogDTO? {
        let snap = try await catalogDoc().getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: CatalogDTO.self)
    }
```

### Task 6.3: `FirestoreCatalogLoader` (remote + bundled fallback)

**Files:**
- Create: `Fullball/Services/Firestore/FirestoreCatalogLoader.swift`

- [ ] **Step 1: Write the loader**

```swift
import Foundation

/// Resolves the catalog from Firestore (`catalog/current`); falls back to the
/// bundled JSON on miss/offline/error. Banners + fixtures stay bundled.
@MainActor
struct FirestoreCatalogLoader: CatalogLoading {
    let client: FirestoreClient

    func load() async throws -> CatalogData {
        let bundled = try await BundledCatalogLoader().load()
        do {
            guard let dto = try await client.fetchCatalog() else { return bundled }
            return dto.toData(banners: bundled.banners, fixtures: bundled.fixtures)
        } catch {
            return bundled   // offline / permission / decode → bundled identity
        }
    }
}
```

### Task 6.4: Wire loader selection

**Files:**
- Modify: `Fullball/App/AppContainer.swift:108-112` (`catalogLoader`)

- [ ] **Step 1:** Prefer Firestore when available. Update `catalogLoader` (it's `@MainActor`-reachable via bootstrap):

```swift
    @MainActor static func catalogLoader(client: FirestoreClient?) -> any CatalogLoading {
        if let client { return FirestoreCatalogLoader(client: client) }
        if let key = FullballConfig.apiFootballKey {
            return APIFootballCatalogLoader(client: APIFootballClient(apiKey: key))
        }
        return BundledCatalogLoader()
    }
```
Update the single call site in `bootstrap` to pass the `FirestoreClient` it already builds (or `nil` when Firebase isn't configured). Read the surrounding bootstrap to match.

- [ ] **Step 2: Build + test** — Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: Firestore catalog loader with bundled fallback (live-ops metadata)"
```

### Task 6.5: Security rules

**Files:**
- Modify: `firestore.rules`
- Create: `storage.rules`

- [ ] **Step 1: firestore.rules** — add inside the top-level match block:

```
    match /catalog/{doc} {
      allow read: if true;
      allow write: if false;   // authored via console/CI only
    }
```

- [ ] **Step 2: storage.rules**

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /players/{file} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add firestore.rules storage.rules
git commit -m "chore: world-readable catalog + player images rules (no client writes)"
```

> **USER ACTION:** deploy rules (`firebase deploy --only firestore:rules,storage`) and upload the catalog payload to `catalog/current` (Task 7.3).

---

## Phase 7 — Migration, upload, verification

### Task 7.1: Reset local stores on id change

**Files:**
- Modify: `Fullball/App/AppContainer.swift` (schema/bootstrap) or add a one-shot migration flag.

- [ ] **Step 1:** Add a `UserDefaults` version gate, e.g. `catalogSchemaVersion`. On bump (set to `2`), delete the local SwiftData store before building the `ModelContainer` so stale `CardInstance`/pity/lineup rows (old ids) don't dangle. Pre-launch only; document in CLAUDE.md gotchas. Read the existing `ModelContainer` setup to place this.
- [ ] **Step 2: Build + launch on sim**, confirm no crash on first run.
- [ ] **Step 3: Commit** `chore: reset local store on catalog id migration (pre-launch)`.

### Task 7.2: Upload images to Storage

- [ ] **USER/operator step** (documented, not code):
```bash
# requires Firebase CLI + a service account or `firebase login`
cd build/player_images
gsutil -m cp *.jpg gs://<your-bucket>/players/
# or: firebase storage:... per current CLI
```
Verify one in the console + in-app (portrait loads, then offline still loads from disk cache).

### Task 7.3: Upload catalog to Firestore

- [ ] **USER/operator step:** push `Fullball/Resources/catalog.json` (the `{nations,cards}` object) to `catalog/current`. Verify the app reflects a live edit (e.g. tweak one stat in console → relaunch → changed).

### Task 7.4: Docs + final verification

**Files:**
- Modify: `CLAUDE.md` (structure: Storage, PlayerImageStore, catalog loader; test count), `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` (P3 done; rarity now 4 tiers; image delivery), `docs/GAMEPLAY.md` (rarity table, odds).

- [ ] **Step 1:** Update the four docs to match (rarity 4-tier + new odds, 61 cards, Storage images, Firestore catalog, new test count).
- [ ] **Step 2: Full test run** — Expected: all suites PASS.
- [ ] **Step 3: Commit** `docs: update for asset & catalog revamp (4 tiers, 61 cards, Storage images, Firestore catalog)`.

---

## Self-review notes

- **Spec coverage:** Layer A catalog (Tasks 6.x), Layer B images (5.x), 4-tier rarity (2.x), authored names (3.x), curated nations + CSV (1.1/4.2), pipeline (1.2), migration (7.1), rules (6.5), tests throughout. ✓
- **Blocked-on-user gates** are called out inline (CSV curation before Phase 4; Storage enable + uploads in Phase 7; rules deploy). These don't block Phases 2–3 (pure logic) which can land first.
- **Type consistency:** `imageRef` (Card) used by `PlayerImageStore.image(for:)` and Storage path `players/{id}.jpg`; `name`/`epithet` on `Player` consumed by `funnyName` and produced by `build_catalog.py` + `CatalogDTO`. `DiskImageCache.filename` matches the Storage filename.
- **Known soft spots to verify against live code during execution:** exact `Nation` initializer, `GachaEngineTests.frac` helper, `AppContainer.bootstrap` FirestoreClient construction, and the root `.environment` injection site — each task says "read the surrounding code to match."
