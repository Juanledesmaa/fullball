import Foundation

/// A pure snapshot of an upgradeable card's mutable progress. Lets the
/// upgrade math be tested without SwiftData.
struct UpgradeState: Equatable, Sendable {
    var level: Int
    var stars: Int
    var xp: Int
}

/// Pure level / limit-break math. No persistence.
enum UpgradeRules {
    static let baseLevelCap = 10        // at 0 stars
    static let levelsPerStar = 10       // each star raises the cap
    static let xpPerTrain = 60          // xp granted by one "train" action
    static let statBumpPerStar = 2      // each star adds this to every stat
    static let statBumpPerLevel = 1     // each level over 1 adds this to every stat

    /// Maximum level reachable at a given star count.
    static func levelCap(stars: Int) -> Int {
        baseLevelCap + stars * levelsPerStar
    }

    /// XP required to advance from `level` to `level + 1`.
    static func xpToNext(level: Int) -> Int {
        100 + (level - 1) * 50
    }

    /// Coin cost of one train action at the given level.
    static func trainCoinCost(level: Int) -> Int {
        50 * level
    }

    /// Copies consumed to reach `targetStar` (1 for the 1st star, 2 for the
    /// 2nd, …).
    static func copiesForStar(_ targetStar: Int) -> Int { max(1, targetStar) }

    /// Apply gained XP, rolling level up as thresholds are crossed, clamped
    /// to the star-derived level cap.
    static func applyXP(_ state: UpgradeState, gained: Int) -> UpgradeState {
        var s = state
        s.xp += max(0, gained)
        let cap = levelCap(stars: s.stars)
        while s.level < cap {
            let need = xpToNext(level: s.level)
            if s.xp >= need {
                s.xp -= need
                s.level += 1
            } else {
                break
            }
        }
        if s.level >= cap { s.xp = 0 }   // no overflow XP at the cap
        return s
    }

    static func canLimitBreak(_ state: UpgradeState, copies: Int, rarity: Rarity) -> Bool {
        state.stars < rarity.starCap && copies >= copiesForStar(state.stars + 1)
    }

    /// Consume copies to add one star (raising the level cap). Returns the
    /// new state and the remaining copies. No-op if not allowed.
    static func limitBreak(_ state: UpgradeState, copies: Int, rarity: Rarity)
        -> (state: UpgradeState, copies: Int) {
        guard canLimitBreak(state, copies: copies, rarity: rarity) else { return (state, copies) }
        let cost = copiesForStar(state.stars + 1)
        var s = state
        s.stars += 1
        return (s, copies - cost)
    }

    /// Effective stats after level + star bumps.
    static func effectiveStats(base: Stats, level: Int, stars: Int) -> Stats {
        let levelBonus = (level - 1) * statBumpPerLevel
        let starBonus = stars * statBumpPerStar
        let bump = levelBonus + starBonus
        return Stats(pace: base.pace + bump,
                     shooting: base.shooting + bump,
                     passing: base.passing + bump,
                     defending: base.defending + bump)
    }
}
