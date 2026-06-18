import Foundation

/// A currency grant (any subset). Used by milestones and exchanges.
struct CurrencyGrant: Equatable, Sendable {
    var coins = 0
    var gems = 0
    var tickets = 0
}

// MARK: - Matchday milestones

struct MilestoneTier: Equatable, Sendable {
    let threshold: Int   // career points required
    let gems: Int
    let tickets: Int
    var grant: CurrencyGrant { CurrencyGrant(gems: gems, tickets: tickets) }
}

/// Career-point milestones that fund pulls from live performance. Pure +
/// testable; the service persists how many have been claimed.
enum Milestones {
    static let tiers: [MilestoneTier] = [
        .init(threshold: 500,  gems: 150,  tickets: 1),
        .init(threshold: 1500, gems: 300,  tickets: 2),
        .init(threshold: 3000, gems: 500,  tickets: 3),
        .init(threshold: 5000, gems: 800,  tickets: 4),
        .init(threshold: 8000, gems: 1200, tickets: 5),
    ]

    /// How many tiers a points total has reached.
    static func earnedCount(_ points: Int) -> Int { tiers.filter { points >= $0.threshold }.count }

    /// Tiers earned but not yet claimed.
    static func newlyClaimable(points: Int, claimed: Int) -> [MilestoneTier] {
        let earned = earnedCount(points)
        guard earned > claimed, claimed >= 0, claimed < tiers.count else { return [] }
        return Array(tiers[claimed..<earned])
    }

    /// The next tier the player is working toward, if any.
    static func next(after points: Int) -> MilestoneTier? { tiers.first { points < $0.threshold } }
}

// MARK: - Form Token exchange

/// Exchange rates converting live-earned Form Tokens into pull currency.
/// This is what closes the loop: play live → Form Tokens → more pulls.
enum ExchangeRates {
    static let formPerTicket = 8
    static let formPerGemPack = 40
    static let gemsPerPack = 250

    static func canBuyTicket(form: Int) -> Bool { form >= formPerTicket }
    static func canBuyGemPack(form: Int) -> Bool { form >= formPerGemPack }
}

// MARK: - Agent economy

/// You're an agent: clients earn you a commission (Cash) on performance, and
/// you sign marquee clients on the transfer market.
enum AgentRules {
    /// Cash paid per match point a fielded client earns (your cut).
    static let cashPerPoint = 3

    static func commission(forPoints points: Int) -> Int { max(0, points) * cashPerPoint }
}

/// Transfer-market pricing for signing a specific client outright.
enum TransferRules {
    static func price(rarity: Rarity, overall: Int) -> Int {
        let base: Int
        switch rarity {
        case .icon:   base = 6000
        case .gold:   base = 1200
        case .silver: base = 500
        case .bronze: base = 200
        }
        // Scale a little by overall so standout clients cost more.
        return base + overall * 40
    }
}

// MARK: - Live match rules

/// Rules for paid, fixed-duration live matches.
enum LiveRules {
    static let entryFeeCoins = 200          // cost to enter a match
    static let fullTimeMinute = 90          // match length in game-minutes
    static let realDurationSeconds = 40     // wall-clock length of a match
    static let winBonusTarget = 150         // match points needed for the bonus
    static let winBonusTickets = 1          // bonus paid when target is met

    static var realDuration: Duration { .seconds(realDurationSeconds) }
}

/// Cost to manually refresh the match slate with Gems (premium). Free
/// refreshes still happen every time block; this skips the wait. Escalates
/// per refresh within a block to keep the sink meaningful.
enum RefreshRules {
    static let baseCost = 150
    /// Gems for the next refresh, given how many manual refreshes already
    /// happened this block (0 → 150, 1 → 300, 2 → 450 …).
    static func cost(forCount n: Int) -> Int { baseCost * (n + 1) }
}

// MARK: - Futsal engine tuning

/// All tunable constants for the 5-a-side resolution engine. Pure; the engine
/// reads these so balancing is a one-file change.
enum FutsalRules {
    static let possessionCount = 14         // alternating possessions per match

    // Chance creation (per attacking possession).
    static let baseChance = 0.45
    static let strengthWeight = 0.004       // per point of midfield diff ((passing+pace)/2, atk - def)
    static let formationEdgeWeight = 0.05   // per RPS edge step
    static let mentalityWeight = 0.06       // per mentality step, attacker minus defender
    static let counterEdgeWeight = 0.04     // per counter RPS edge step
    static let chanceFloor = 0.05, chanceCeil = 0.90

    // Shot resolution (when a chance is created).
    static let baseGoal = 0.30
    static let shotWeight = 0.004           // per point of (shooting - GK defending)
    static let styleEdgeWeight = 0.03       // per shooter-vs-marker RPS edge step
    static let saveBand = 0.30              // share of non-goal outcomes that are saves vs misses
    static let goalFloor = 0.03, goalCeil = 0.90

    // Marking: a strong marker on the danger man reduces their effective shooting.
    static let markWeight = 0.20            // fraction of marker.defending subtracted

    // Reward premium (used by the rewards phase; defined here with engine tuning).
    static let maxTacticsBonus = 1.5        // cap on the active-play payout multiplier
}

/// Per-player energy: tired players underperform. Pure functions; storage and
/// Gem-refill wiring land in a later phase.
enum EnergyRules {
    static let maxEnergy = 100
    static let penaltyThreshold = 50        // at/above this, no penalty
    static let maxPenaltyFraction = 0.30    // worst-case stat reduction at 0 energy
    static let drainPerMatch = 20           // outfield drain when fielded
    static let captainExtraDrain = 10       // captain drains 30 total (×2 workload)
    static let regenPerMinute = 0.25        // ~6.7h for a full refill

    /// Linear stat scaling below the threshold; identity at/above it.
    static func applyPenalty(to s: Stats, energy: Int) -> Stats {
        guard energy < penaltyThreshold else { return s }
        let t = Double(max(0, energy)) / Double(penaltyThreshold)  // 0..1
        let factor = 1.0 - maxPenaltyFraction * (1.0 - t)          // 0.70..1.0
        func scale(_ v: Int) -> Int { Int((Double(v) * factor).rounded()) }
        return Stats(pace: scale(s.pace), shooting: scale(s.shooting),
                     passing: scale(s.passing), defending: scale(s.defending))
    }

    static func regen(from energy: Int, minutesElapsed: Double) -> Int {
        // .rounded(.down) is intentional: regen is slightly stingy (conservative floor).
        min(maxEnergy, energy + Int((regenPerMinute * minutesElapsed).rounded(.down)))
    }
}
