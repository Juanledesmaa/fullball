import Foundation

/// Pure gacha math: rarity rolls, soft/hard pity, and the featured 50/50.
/// Given a `PityState` + `RandomProvider`, returns a `RollOutcome` and the
/// next `PityState`. No persistence, no wallet — fully testable.
enum GachaEngine {
    static let softPityStart = 40   // odds begin ramping at this pull
    static let hardPity = 50        // guaranteed Icon at this pull

    /// Icon probability for the n-th pull since the last Icon (1-based).
    /// Flat at base until soft pity, then ramps to a guarantee at hard pity.
    static func iconOdds(forPullNumber n: Int) -> Double {
        let base = Rarity.icon.baseOdds
        if n >= hardPity { return 1.0 }
        if n < softPityStart { return base }
        let span = Double(hardPity - (softPityStart - 1))      // 11
        let step = (1.0 - base) / span
        return min(1.0, base + Double(n - (softPityStart - 1)) * step)
    }

    /// Resolve a rarity from a roll in [0,1) given the current pull number.
    static func rarity(forPullNumber n: Int, roll: Double) -> Rarity {
        let ico = iconOdds(forPullNumber: n)
        let nonIconBase = Rarity.bronze.baseOdds + Rarity.silver.baseOdds
            + Rarity.gold.baseOdds + Rarity.epic.baseOdds   // 0.997
        let scale = (1.0 - ico) / nonIconBase

        var cumulative = 0.0
        for rarity in [Rarity.bronze, .silver, .gold, .epic] {
            cumulative += rarity.baseOdds * scale
            if roll < cumulative { return rarity }
        }
        return .icon
    }

    /// Perform one roll against a banner. `pool` is the full card catalog.
    static func roll<R: RandomProvider>(
        banner: Banner,
        pity: PityState,
        pool: [Card],
        provider: inout R
    ) -> RollOutcome {
        let n = pity.pullsSinceIcon + 1
        let roll = provider.nextUnit()
        let rarity = rarity(forPullNumber: n, roll: roll)

        func pick(_ cards: [Card]) -> Card {
            let source = cards.isEmpty ? pool : cards
            return source[provider.nextInt(source.count)]
        }

        if rarity == .icon {
            let icons = pool.filter { $0.rarity == .icon }
            let featured = icons.filter { banner.featuredCardIDs.contains($0.id) }
            let offBanner = icons.filter { !banner.featuredCardIDs.contains($0.id) }

            var nextGuarantee = pity.guaranteeFeatured
            let chosen: Card

            if banner.type == .featured && !featured.isEmpty {
                if pity.guaranteeFeatured {
                    chosen = pick(featured)
                    nextGuarantee = false
                } else {
                    let coin = provider.nextUnit()
                    if coin < 0.5 {
                        chosen = pick(featured)
                        nextGuarantee = false
                    } else {
                        chosen = pick(offBanner.isEmpty ? featured : offBanner)
                        nextGuarantee = !offBanner.isEmpty
                    }
                }
            } else {
                chosen = pick(icons)
            }

            return RollOutcome(
                card: chosen,
                pityAfter: PityState(pullsSinceIcon: 0, guaranteeFeatured: nextGuarantee),
                wasGuaranteedIcon: true
            )
        } else {
            let chosen = pick(pool.filter { $0.rarity == rarity })
            return RollOutcome(
                card: chosen,
                pityAfter: PityState(pullsSinceIcon: n, guaranteeFeatured: pity.guaranteeFeatured),
                wasGuaranteedIcon: false
            )
        }
    }
}
